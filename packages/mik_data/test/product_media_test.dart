import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/product_media.dart';

import 'support/onboarding_fixtures.dart';
import 'support/pim_fixtures.dart';

const mediaId = '11111111-1111-4111-8111-111111111110';
const imageUrl = 'https://cdn.example.test/product-image';
final imageBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ioAAAAASUVORK5CYII=',
  ),
);

class MediaServer {
  final String app;
  MediaServer(this.app);
  final requests = <http.Request>[];
  Map<String, dynamic>? body;
  String? requestKey;
  String status = 'PENDING';
  bool loseRequest = false, loseComplete = false, wrongOwner = false;
  int puts = 0;
  Map<String, dynamic> get file => {
    'mediaId': mediaId,
    'platformId': 'mik',
    'businessId': 12345678,
    'entityType': 'PRODUCT',
    'entityId': wrongOwner ? mediaId : productId,
    'purpose': 'PRODUCT_IMAGE',
    'visibility': 'PUBLIC',
    'status': status,
    'revision': status == 'READY' ? 2 : 1,
    if (body != null) ...{
      'fileName': body!['fileName'],
      'contentType': body!['contentType'],
      'size': body!['size'],
    },
    if (status == 'READY') 'publicUrl': imageUrl,
  };
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    if (request.url.host == 'storage.example.test') {
      expectSync(request.method, 'PUT');
      expectSync(request.headers.containsKey('authorization'), isFalse);
      expectSync(request.headers.containsKey('x-app-id'), isFalse);
      expectSync(request.headers['Content-MD5'], body!['checksumMD5']);
      expectSync(request.headers['x-amz-meta-upload-id'], mediaId);
      expectSync(request.bodyBytes, imageBytes);
      puts++;
      return http.Response('', 200);
    }
    expectSync(request.headers['x-app-id'], app);
    if (request.url.path.endsWith('/uploads')) {
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      if (body != null) {
        expectSync(data, body);
        expectSync(request.headers['idempotency-key'], requestKey);
      }
      body = data;
      requestKey = request.headers['idempotency-key'];
      if (loseRequest) {
        loseRequest = false;
        throw TimeoutException('lost upload acceptance');
      }
      return jsonResponse({
        'file': file,
        if (status == 'PENDING')
          'upload': {
            'method': 'PUT',
            'url':
                'https://storage.example.test/pending-image?signature=fixture',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
            'headers': {
              'Content-Type': data['contentType'],
              'Content-MD5': data['checksumMD5'],
              'x-amz-meta-upload-id': mediaId,
            },
          },
      });
    }
    if (request.url.path.endsWith('/complete')) {
      expectSync(jsonDecode(request.body), isEmpty);
      expectSync(puts, greaterThan(0));
      status = 'READY';
      if (loseComplete) {
        loseComplete = false;
        throw TimeoutException('lost completion');
      }
      return jsonResponse({'file': file});
    }
    return jsonResponse({'file': file});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app uploads bytes without forwarding API credentials and resolves the real URL',
      () async {
        final server = MediaServer(app);
        final context = pimFixture(
          MockClient(server.respond),
          appId: app,
        ).context;
        final client = ProductMediaFX(context);
        expect(
          await client.upload(productId, bytes: imageBytes, name: 'image.png'),
          mediaId,
        );
        expect(server.puts, 1);
        expect(server.body!['purpose'], 'PRODUCT_IMAGE');
        expect(server.body!['entityId'], productId);
        expect(server.body!['size'], imageBytes.length);
        expect(await client.url(productId, mediaId), imageUrl);
        expect(await client.restore(productId), isNotNull);
        await client.clear(productId);
        expect(await client.restore(productId), isNull);
      },
    );
    test(
      '$app lost replies resume the same upload after reopening and reject a different file',
      () async {
        final server = MediaServer(app)..loseRequest = true;
        final context = pimFixture(
          MockClient(server.respond),
          appId: app,
        ).context;
        var client = ProductMediaFX(context);
        await expectLater(
          client.upload(productId, bytes: imageBytes, name: 'image.png'),
          throwsA(anything),
        );
        client = ProductMediaFX(context);
        await expectLater(
          client.upload(
            productId,
            bytes: Uint8List.fromList([1]),
            name: 'other.png',
          ),
          throwsStateError,
        );
        server.loseComplete = true;
        await expectLater(
          client.upload(productId, bytes: imageBytes, name: 'image.png'),
          throwsA(anything),
        );
        client = ProductMediaFX(context);
        expect(await client.upload(productId), mediaId);
        expect(server.puts, 1);
        expect(
          server.requests.where((r) => r.url.path.endsWith('/uploads')),
          hasLength(2),
        );
      },
    );
    test('$app refuses cross-product media and invalid file inputs', () async {
      final server = MediaServer(app)
        ..status = 'READY'
        ..wrongOwner = true;
      final context = pimFixture(
        MockClient(server.respond),
        appId: app,
      ).context;
      final client = ProductMediaFX(context);
      await expectLater(client.url(productId, mediaId), throwsFormatException);
      await expectLater(
        client.upload(productId, bytes: imageBytes, name: 'photo.svg'),
        throwsStateError,
      );
      expect(server.requests, hasLength(1));
    });
  }
}
