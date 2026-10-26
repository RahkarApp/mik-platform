import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/debug_http_client.dart';

void main() {
  test('logs requests and error responses without exposing credentials', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? text, {int? wrapWidth}) { logs.add(text ?? ''); };
    addTearDown(() => debugPrint = original);
    final client = DebugHttpClient(MockClient((request) async {
      expect(request.url.queryParameters['token'], 'url-secret');
      expect(jsonDecode(request.body)['otp'], '12345');
      return http.Response(jsonEncode({
        'error': {'code': 'VALIDATION_FAILED', 'message': 'Invalid calendar'},
        'accessToken': 'response-secret',
      }), 400);
    }));
    final response = await client.post(Uri.parse('https://example.test/test?token=url-secret'),
        headers: {'Authorization': 'Bearer header-secret'},
        body: jsonEncode({'otp': '12345', 'name': 'test'}));
    expect(response.statusCode, 400);
    expect(jsonDecode(response.body)['accessToken'], 'response-secret');
    final output = logs.join('\n');
    expect(output, contains('REQUEST POST'));
    expect(output, contains('status=400'));
    expect(output, contains('Invalid calendar'));
    expect(output, contains('VALIDATION_FAILED'));
    for (final secret in ['url-secret', 'header-secret', 'response-secret', '12345']) {
      expect(output, isNot(contains(secret)));
    }
    client.close();
  });
}
