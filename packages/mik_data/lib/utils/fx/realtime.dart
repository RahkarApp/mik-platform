import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:get/get.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';

class RealtimeUpdate {
  final Set<String> resources;
  final bool resync;
  final Object? failure;
  const RealtimeUpdate({
    this.resources = const {},
    this.resync = false,
    this.failure,
  });
}

/// Server events invalidate reads; they never replace documents or confirm a mutation.
class RealtimeFX {
  static final _clients = Expando<RealtimeFX>();
  static RealtimeFX forContext(
    BusinessContext context, {
    WebSocketChannel Function(Uri)? connect,
    Duration retryDelay = const Duration(seconds: 1),
  }) => _clients[context] ??= RealtimeFX(
    context,
    connect: connect,
    retryDelay: retryDelay,
  );
  static void pauseFor(BusinessContext context) =>
      _clients[context]?.pause(resetCursor: true);
  static void resumeFor(BusinessContext context) {
    final client = _clients[context];
    if (client?._enabled == true) unawaited(client!.start());
  }

  final BusinessContext context;
  final WebSocketChannel Function(Uri) connect;
  final Duration retryDelay;
  final _updates = StreamController<RealtimeUpdate>.broadcast();
  Stream<RealtimeUpdate> get updates => _updates.stream;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry, _renew, _handshake;
  String? _cursor;
  int _generation = 0, _attempts = 0;
  final _enabledState = false.obs;
  RxBool get enabled => _enabledState;
  bool get _enabled => _enabledState.value;
  set _enabled(bool value) => _enabledState.value = value;
  bool _connecting = false, _ready = false, _reported = false;
  RealtimeFX(
    this.context, {
    WebSocketChannel Function(Uri)? connect,
    this.retryDelay = const Duration(seconds: 1),
  }) : connect = connect ?? WebSocketChannel.connect;
  bool get _valid => context.valid && context.selectedBranch != null;
  Uri get uri => API.origin.replace(
    scheme: API.origin.scheme == 'https' ? 'wss' : 'ws',
    // Dart's native WebSocket otherwise forwards an unspecified WS port as 0.
    port: API.origin.port,
    path: '/v1/realtime',
  );

  Future<void> start({bool reload = false}) async {
    _enabled = true;
    if (!_valid || _connecting || _channel != null) return;
    _retry?.cancel();
    final generation = ++_generation;
    _connecting = true;
    try {
      if (reload) await _resync(generation);
      final token = await context.auth.accessToken();
      if (generation != _generation || !_valid) return;
      if (token == null) throw const AuthError(401, 'SESSION_INVALID');
      final channel = connect(uri);
      _channel = channel;
      _ready = false;
      // Listen before ready: connection failures can arrive through both futures and streams.
      _subscription = channel.stream
          .asyncMap((message) async {
            if (generation == _generation) {
              await _message(message, generation, channel);
            }
          })
          .listen(
            (_) {},
            onError: (Object failure) => _lost(generation, failure),
            onDone: () => _lost(
              generation,
              channel.closeCode == 4401
                  ? const AuthError(401, 'REALTIME_ACCESS_CHANGED')
                  : channel.closeCode == 4009
                  ? null
                  : const AuthError(
                      0,
                      'REALTIME_DISCONNECTED',
                      retryable: true,
                    ),
            ),
          );
      await channel.ready.timeout(const Duration(seconds: 10));
      if (generation != _generation || !_valid) return;
      channel.sink.add(
        jsonEncode({
          'type': 'authenticate',
          'accessToken': token,
          'businessId': context.session.business.businessId,
          if (_cursor != null) 'cursor': _cursor,
        }),
      );
      _handshake = Timer(
        const Duration(seconds: 10),
        () => _lost(
          generation,
          TimeoutException('Realtime authentication timeout'),
        ),
      );
      final expires = context.auth.current!.accessExpiresAt.subtract(
        const Duration(seconds: 30),
      );
      final delay = expires.difference(DateTime.now().toUtc());
      _renew = Timer(delay.isNegative ? Duration.zero : delay, () {
        pause();
        if (_enabled) unawaited(start());
      });
    } catch (failure) {
      _lost(generation, failure);
    } finally {
      if (generation == _generation) _connecting = false;
    }
  }

  String _validCursor(String value) {
    if (value.length > 200 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw const FormatException('Invalid realtime cursor');
    }
    final data = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(value))),
    );
    if (data is! List ||
        data.length != 2 ||
        data.first is! String ||
        data.last is! int ||
        (data.last as int) < 0 ||
        (data.last as int) > 9007199254740991) {
      throw const FormatException('Invalid realtime cursor');
    }
    FinancialReportPage.uuid(data.first as String);
    if (base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '') !=
        value) {
      throw const FormatException('Noncanonical realtime cursor');
    }
    return value;
  }

  Future<void> _message(
    dynamic message,
    int generation,
    WebSocketChannel channel,
  ) async {
    if (!_valid) {
      stop();
      return;
    }
    if (message is! String) {
      throw const FormatException('Invalid realtime frame');
    }
    final data = RemoteJson(jsonDecode(message));
    switch (data.text('type')) {
      case 'ready':
        if (_ready ||
            data.number('businessId') != context.session.business.businessId ||
            data.number('protocolVersion') != 1) {
          throw const FormatException('Unexpected realtime session');
        }
        _ready = true;
        _handshake?.cancel();
      case 'changes':
        if (!_ready) throw const FormatException('Realtime is not ready');
        final cursor = _validCursor(data.text('cursor'));
        final resources = <String>{}, ids = <String>{};
        final rows = data.items('items', RemoteJson.new);
        if (rows.length > 50) {
          throw const FormatException('Invalid realtime batch');
        }
        for (final row in rows) {
          FinancialReportPage.uuid(row.text('eventId'));
          if (!ids.add(row.text('eventId')) ||
              row.number('revision') < 1 ||
              row.number('revision') > 9007199254740991 ||
              !RegExp(r'^[a-z][a-z0-9-]*\.[a-z][a-z0-9-]*$')
                  .hasMatch(row.text('resource'))) {
            throw const FormatException('Invalid realtime reference');
          }
          row.text('entityId');
          FinancialReportPage.date(row.text('occurredAt'));
          resources.add(row.text('resource'));
        }
        // Queue invalidation before acknowledging. A new app process starts with a full snapshot.
        _updates.add(RealtimeUpdate(resources: Set.unmodifiable(resources)));
        _cursor = cursor;
        channel.sink.add(jsonEncode({'type': 'ack', 'cursor': cursor}));
        _reported = false;
        _attempts = 0;
      case 'resync_required':
        if (!_ready ||
            ![
              'CURSOR_UNAVAILABLE',
              'ACCESS_CHANGED',
            ].contains(data.text('reason'))) {
          throw const FormatException('Invalid realtime resynchronization');
        }
        final cursor = _validCursor(data.text('cursor'));
        await _resync(generation);
        if (generation == _generation && _valid) {
          _cursor = cursor;
          _reported = false;
          _attempts = 0;
        }
      default:
        throw const FormatException('Unknown realtime message');
    }
  }

  Future<void> _resync(int generation) async {
    try {
      await context.refreshAccess();
      if (generation == _generation && _valid) {
        _updates.add(const RealtimeUpdate(resync: true));
      }
    } catch (failure) {
      if (generation == _generation ||
          _enabled && context.valid && context.selectedBranch == null) {
        _updates.add(RealtimeUpdate(resync: true, failure: failure));
        stop();
      }
      rethrow;
    }
  }

  void _lost(int generation, Object? failure) {
    if (generation != _generation) return;
    pause();
    if (failure != null && !_reported) {
      _reported = true;
      _updates.add(RealtimeUpdate(failure: failure));
    }
    if (!_enabled || !_valid) return;
    if (failure is AuthError && failure.requiresLogin) {
      stop();
      return;
    }
    final factor = 1 << (_attempts > 5 ? 5 : _attempts++);
    _retry = Timer(
      retryDelay * factor,
      () => unawaited(start(reload: failure is AuthError)),
    );
  }

  void pause({bool resetCursor = false}) {
    _generation++;
    _connecting = false;
    _ready = false;
    _retry?.cancel();
    _renew?.cancel();
    _handshake?.cancel();
    final subscription = _subscription, channel = _channel;
    _subscription = null;
    _channel = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (channel != null) unawaited(channel.sink.close().catchError((_) {}));
    if (resetCursor) _cursor = null;
  }

  void stop() {
    _enabled = false;
    pause(resetCursor: true);
  }
}

/// Coalesce bursts and run one read at a time; never restart a form or a mutation.
class RealtimeWatch {
  final Future<void> Function() refresh;
  final void Function()? invalidate;
  final bool Function()? busy;
  late final void Function(Object) _report;
  late final StreamSubscription<RealtimeUpdate> _subscription;
  Timer? _timer;
  bool _closed = false, _running = false, _dirty = false;
  RealtimeWatch(
    RealtimeFX client,
    Set<String> resources,
    this.refresh, {
    this.invalidate,
    this.busy,
  }) {
    _report = (failure) =>
        client._updates.add(RealtimeUpdate(failure: failure));
    _subscription = client.updates.listen((update) {
      if (!update.resync && !update.resources.any(resources.contains)) return;
      if (update.resync) invalidate?.call();
      _dirty = true;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 250), _run);
    });
  }
  Future<void> _run() async {
    if (_closed || _running) return;
    _running = true;
    try {
      while (_dirty && !_closed) {
        if (busy?.call() == true) {
          _timer = Timer(const Duration(milliseconds: 50), _run);
          break;
        }
        _dirty = false;
        try {
          await refresh();
        } catch (failure) {
          _report(failure);
        }
      }
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    unawaited(_subscription.cancel());
  }
}
