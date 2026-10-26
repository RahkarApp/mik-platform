import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'support/onboarding_fixtures.dart';
import 'support/pim_fixtures.dart';

String cursor(int sequence) => base64Url
    .encode(
      utf8.encode(
        jsonEncode(['99999999-9999-4999-8999-999999999999', sequence]),
      ),
    )
    .replaceAll('=', '');
Future<void> until(bool Function() ready) async {
  for (var i = 0; i < 400 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(ready(), isTrue, reason: 'Expected realtime progress');
}

class SocketServer {
  late HttpServer server;
  final sockets = <WebSocket>[];
  final auths = <Map<String, dynamic>>[], acks = <Map<String, dynamic>>[];
  final uris = <Uri>[];
  Future<void> open() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((frame) {
        final data = jsonDecode(frame as String) as Map<String, dynamic>;
        if (data['type'] == 'authenticate') {
          auths.add(data);
          socket.add(
            jsonEncode({
              'type': 'ready',
              'businessId': 12345678,
              'protocolVersion': 1,
            }),
          );
        } else {
          acks.add(data);
        }
      });
    });
  }

  WebSocketChannel connect(Uri uri) {
    uris.add(uri);
    return WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/v1/realtime'),
    );
  }

  void changes(
    int sequence, {
    String resource = 'accounting.sale',
  }) => sockets.last.add(
    jsonEncode({
      'type': 'changes',
      'cursor': cursor(sequence),
      'items': [
        {
          'eventId':
              '11111111-1111-4111-8111-${sequence.toString().padLeft(12, '0')}',
          'resource': resource,
          'entityId': productId,
          'revision': sequence,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    }),
  );
  Future<void> resync(
    int sequence, {
    String reason = 'CURSOR_UNAVAILABLE',
  }) async {
    sockets.last.add(
      jsonEncode({
        'type': 'resync_required',
        'cursor': cursor(sequence),
        'reason': reason,
      }),
    );
    await sockets.last.close(4009);
  }

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  }
}

Future<BusinessContext> realtimeContext(
  String app, {
  bool Function()? denied,
}) async {
  final context = pimFixture(
    MockClient((request) async {
      if (request.url.path.endsWith('/branches')) {
        return jsonResponse({
          'items': [fixtureResult()['branch']],
          'nextCursor': null,
        });
      }
      if (denied?.call() == true) {
        return http.Response(
          jsonEncode({
            'error': {'code': 'FORBIDDEN'},
          }),
          403,
        );
      }
      final business = request.url.queryParameters['scopeType'] == 'BUSINESS';
      return jsonResponse({
        ...fixtureAuthorization(['accounting.sale.read']),
        'scopeType': business ? 'BUSINESS' : 'BRANCH',
        'scopeId': business ? '12345678' : branch,
      });
    }),
    appId: app,
  ).context;
  await context.selectBranch((await context.branches()).single);
  return context;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app native WebSocket resync, ack, reconnect cursor and scope lifecycle',
      () async {
        final server = SocketServer();
        await server.open();
        final context = await realtimeContext(app);
        final selected = context.selectedBranch;
        final client = RealtimeFX.forContext(
          context,
          connect: server.connect,
          retryDelay: const Duration(milliseconds: 10),
        );
        final updates = <RealtimeUpdate>[];
        final subscription = client.updates.listen(updates.add);
        addTearDown(() async {
          client.stop();
          await subscription.cancel();
          await server.close();
        });
        await client.start();
        await until(() => server.auths.length == 1);
        expect(server.auths.single, {
          'type': 'authenticate',
          'accessToken': 'access',
          'businessId': 12345678,
        });
        expect(server.uris.single.path, '/v1/realtime');
        expect(server.uris.single.port, API.origin.port);
        expect(server.uris.single.port, isNot(0));
        expect(server.uris.single.hasQuery, isFalse);
        expect(server.uris.single.userInfo, isEmpty);
        await server.resync(0);
        await until(() => server.auths.length == 2);
        expect(server.auths.last['cursor'], cursor(0));
        expect(updates.any((u) => u.resync), isTrue);
        expect(context.selectedBranch, same(selected));
        server.changes(1);
        await until(() => server.acks.length == 1);
        expect(server.acks.last, {'type': 'ack', 'cursor': cursor(1)});
        expect(updates.last.resources, {'accounting.sale'});
        await server.sockets.last.close(1011);
        await until(() => server.auths.length == 3);
        expect(server.auths.last['cursor'], cursor(1));
        final received = updates.length;
        context.clearAccess();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(server.auths.length, 3);
        expect(updates.length, received);
      },
    );
    test(
      '$app access reset clears revoked scope and does not acknowledge malformed references',
      () async {
        var denied = false;
        final server = SocketServer();
        await server.open();
        final context = await realtimeContext(app, denied: () => denied);
        final client = RealtimeFX.forContext(
          context,
          connect: server.connect,
          retryDelay: const Duration(milliseconds: 10),
        );
        final updates = <RealtimeUpdate>[];
        final subscription = client.updates.listen(updates.add);
        addTearDown(() async {
          client.stop();
          await subscription.cancel();
          await server.close();
        });
        await client.start();
        await until(() => server.auths.length == 1);
        server.sockets.last.add(
          jsonEncode({
            'type': 'changes',
            'cursor': cursor(1),
            'items': [
              {'eventId': 'not-a-uuid'},
            ],
          }),
        );
        await until(() => updates.any((u) => u.failure != null));
        expect(server.acks, isEmpty);
        await until(() => server.auths.length == 2);
        denied = true;
        await server.resync(2, reason: 'ACCESS_CHANGED');
        await until(() => updates.any((u) => u.resync && u.failure != null));
        expect(context.selectedBranch, isNull);
        expect(context.businessAuthorization, isNull);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(server.auths.length, 2);
      },
    );
    test(
      '$app reader invalidation coalesces bursts and queues changes during a read',
      () async {
        final server = SocketServer();
        await server.open();
        final context = await realtimeContext(app);
        final client = RealtimeFX.forContext(context, connect: server.connect);
        var reads = 0;
        var busy = true;
        final waiting = Completer<void>();
        final watch = RealtimeWatch(client, {'pim.product'}, () async {
          reads++;
          if (reads == 1) await waiting.future;
        }, busy: () => busy);
        addTearDown(() async {
          watch.dispose();
          client.stop();
          await server.close();
        });
        await client.start();
        await until(() => server.auths.isNotEmpty);
        server.changes(1, resource: 'pim.product');
        server.changes(2, resource: 'pim.product');
        server.changes(3, resource: 'pim.product');
        await until(() => server.acks.length == 3);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(reads, 0);
        busy = false;
        await until(() => reads == 1);
        expect(server.acks.length, 3);
        server.changes(4, resource: 'pim.product');
        await until(() => server.acks.length == 4);
        waiting.complete();
        await until(() => reads == 2);
        server.changes(5, resource: 'accounting.sale');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(reads, 2);
        watch.dispose();
        server.changes(6, resource: 'pim.product');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(reads, 2);
      },
    );
  }
}

class HostChannel implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  @override
  late final WebSocketSink sink = HostSink(this);
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  Future<void> get ready => Future.value();
  @override
  int? closeCode;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class HostSink implements WebSocketSink {
  final HostChannel channel;
  HostSink(this.channel);
  @override
  void add(dynamic value) {
    final data = jsonDecode(value as String) as Map<String, dynamic>;
    channel.sent.add(data);
    if (data['type'] == 'authenticate') {
      channel.incoming.add(
        jsonEncode({
          'type': 'ready',
          'businessId': 12345678,
          'protocolVersion': 1,
        }),
      );
    }
  }

  @override
  Future<void> close([int? code, String? reason]) {
    channel.closeCode = code ?? 1000;
    return channel.incoming.close();
  }

  @override
  Future<void> get done => channel.incoming.done;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
