import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Logs at the transport boundary so both modern and legacy APIs are visible.
class DebugHttpClient extends http.BaseClient {
  final http.Client inner;
  static int _sequence = 0;

  static Future<http.StreamedResponse> sendRequest(http.BaseRequest request) {
    // BaseRequest.send owns and closes its client after the response is consumed.
    final client = http.Client();
    return http.runWithClient(() => request.send(), () => DebugHttpClient(client));
  }

  DebugHttpClient(this.inner);

  static final _secret = RegExp(
    r'api.?key|private.?key|token|secret|password|credential|pairing.?code|authorization|signature|cookie|otp|^code$|phone|mobile|national|iban|accountnumber|cardnumber|provideraccountreference',
    caseSensitive: false,
  );
  static Object? _safe(Object? value, {bool error = false}) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(),
          _secret.hasMatch(key.toString()) && !(error && key == 'code')
              ? '[REDACTED]' : _safe(item, error: key == 'error')));
    }
    if (value is List) return value.map((item) => _safe(item)).toList();
    return value;
  }

  static String _json(List<int> bytes) {
    try {
      return jsonEncode(_safe(jsonDecode(utf8.decode(bytes))));
    } catch (_) {
      return '[non-JSON body: ${bytes.length} bytes]';
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!kDebugMode) return inner.send(request);
    final tag = '[HTTP #${++_sequence}]';
    final watch = Stopwatch()..start();
    final url = request.url.replace(
      userInfo: '',
      queryParameters: request.url.hasQuery
          ? request.url.queryParametersAll.map((key, values) => MapEntry(
              key, _secret.hasMatch(key) ? ['[REDACTED]'] : values))
          : null,
    );
    debugPrint('$tag REQUEST ${request.method} $url');
    // Only context headers are logged; credentials never enter the log.
    debugPrint('$tag CONTEXT ${jsonEncode({
      for (final entry in request.headers.entries)
        if (['x-app-id', 'x-branch-id', 'content-type'].contains(entry.key.toLowerCase()))
          entry.key: entry.value,
    })}');
    if (request is http.Request) {
      debugPrint('$tag BODY ${_json(request.bodyBytes)}');
    } else if (request is http.MultipartRequest) {
      debugPrint('$tag MULTIPART ${jsonEncode(_safe(request.fields))} '
          'files=${request.files.length}');
    }
    try {
      final response = await inner.send(request);
      debugPrint('$tag RESPONSE status=${response.statusCode} '
          'elapsed=${watch.elapsedMilliseconds}ms '
          'requestId=${response.headers['x-request-id']}');
      final bytes = <int>[];
      var oversized = false;
      // Observe the stream without buffering or delaying delivery to its caller.
      final stream = response.stream.map((chunk) {
        if (!oversized && bytes.length + chunk.length <= 65536) {
          bytes.addAll(chunk);
        } else {
          oversized = true;
          bytes.clear();
        }
        return chunk;
      }).handleError((Object error, StackTrace stack) {
        debugPrint('$tag STREAM ERROR ${error.runtimeType}');
        Error.throwWithStackTrace(error, stack);
      });
      return http.StreamedResponse(
        _loggedBody(stream, bytes, () => oversized, tag),
        response.statusCode,
        contentLength: response.contentLength,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
        request: response.request,
      );
    } catch (error) {
      debugPrint('$tag FAILED ${error.runtimeType} elapsed=${watch.elapsedMilliseconds}ms');
      rethrow;
    }
  }

  Stream<List<int>> _loggedBody(Stream<List<int>> stream, List<int> bytes,
      bool Function() oversized, String tag) async* {
    yield* stream;
    debugPrint('$tag RESPONSE BODY ${oversized() ? '[body exceeds 64 KB]' : _json(bytes)}');
  }

  @override
  void close() => inner.close();
}
