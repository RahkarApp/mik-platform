import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';

/// Public product images are resolved by Media; never construct a CDN URL from an ID.
class ProductMediaFX {
  static final _clients = Expando<ProductMediaFX>();
  static ProductMediaFX forContext(BusinessContext context) =>
      _clients[context] ??= ProductMediaFX(context);
  final BusinessContext context;
  final FlutterSecureStorage storage;
  final _urls = <String, Future<String>>{};
  ProductMediaFX(this.context, {this.storage = const FlutterSecureStorage()});
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId/media';
  String key(String productId) =>
      'product.media.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$productId';
  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
  }) async {
    context.check();
    final result = await context.auth.request(
      method,
      path,
      data: body,
      idempotencyKey: idempotencyKey,
    );
    context.check();
    return result;
  }

  Uri publicUrl(String value) {
    final uri = Uri.parse(value);
    if (!['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid media URL');
    }
    return uri;
  }

  RemoteJson file(Object? value, String productId, {String? mediaId}) {
    final data = RemoteJson(value);
    if (!Uuid.isValidUUID(fromString: data.text('mediaId')) ||
        mediaId != null && data.text('mediaId') != mediaId ||
        data.number('businessId') != businessId ||
        data.text('platformId') != 'mik' ||
        data.text('entityType') != 'PRODUCT' ||
        data.text('entityId') != productId ||
        data.text('purpose') != 'PRODUCT_IMAGE' ||
        data.text('visibility') != 'PUBLIC' ||
        !['PENDING', 'FINALIZING', 'READY'].contains(data.text('status')) ||
        data.number('revision') < 1) {
      throw const FormatException('Unexpected product media');
    }
    if (data.text('status') == 'READY') publicUrl(data.text('publicUrl'));
    return data;
  }

  Future<String> url(
    String productId,
    String mediaId, {
    bool reload = false,
  }) async {
    context.check();
    final cacheKey = '$productId:$mediaId';
    if (reload) _urls.remove(cacheKey);
    try {
      return await (_urls[cacheKey] ??= () async {
        if (!Uuid.isValidUUID(fromString: mediaId)) {
          throw const FormatException('Invalid media ID');
        }
        final json = RemoteJson(await request('GET', '$base/$mediaId'));
        final row = file(json.value['file'], productId, mediaId: mediaId);
        if (row.text('status') != 'READY') {
          throw const AuthError(409, 'MEDIA_NOT_READY');
        }
        return row.text('publicUrl');
      }());
    } catch (_) {
      _urls.remove(cacheKey);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> restore(String productId) async {
    context.check();
    final saved = await storage.read(key: key(productId));
    context.check();
    if (saved == null) return null;
    final data = RemoteJson(jsonDecode(saved));
    final body = RemoteJson(data.value['body']);
    if (!Uuid.isValidUUID(fromString: data.text('key')) ||
        body.text('entityId') != productId ||
        body.text('purpose') != 'PRODUCT_IMAGE' ||
        data.optionalText('mediaId') != null &&
            !Uuid.isValidUUID(fromString: data.text('mediaId'))) {
      throw const FormatException('Invalid saved media upload');
    }
    return Map.of(data.value);
  }

  Future<void> clear(String productId) async {
    context.check();
    await storage.delete(key: key(productId));
  }

  Future<void> persist(String productId, Map<String, dynamic> attempt) async {
    context.check();
    await storage.write(key: key(productId), value: jsonEncode(attempt));
    context.check();
  }

  Future<String> upload(
    String productId, {
    Uint8List? bytes,
    String? name,
  }) async {
    context.check();
    var attempt = await restore(productId);
    if (bytes != null) {
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw StateError('حجم عکس باید بیشتر از صفر و حداکثر ۱۰ مگابایت باشد.');
      }
      final fileName = (name ?? '').replaceAll(
        RegExp(r'\.jpeg$', caseSensitive: false),
        '.jpg',
      );
      final extension = fileName.split('.').last.toLowerCase();
      if (fileName.isEmpty ||
          fileName.length > 200 ||
          RegExp(r'[\\/\x00-\x1f\x7f]').hasMatch(fileName) ||
          !['jpg', 'png'].contains(extension)) {
        throw StateError('عکس PNG یا JPG با نام معتبر انتخاب کنید.');
      }
      final body = <String, dynamic>{
        'purpose': 'PRODUCT_IMAGE',
        'entityId': productId,
        'fileName': fileName,
        'contentType': extension == 'png' ? 'image/png' : 'image/jpeg',
        'size': bytes.length,
        'checksumMD5': base64Encode(md5.convert(bytes).bytes),
      };
      if (attempt != null && jsonEncode(attempt['body']) != jsonEncode(body)) {
        throw StateError(
          'بارگذاری قبلی تعیین تکلیف نشده؛ همان عکس قبلی را انتخاب کنید.',
        );
      }
      attempt ??= {'key': const Uuid().v4(), 'body': body};
      await persist(productId, attempt);
    }
    if (attempt == null) throw StateError('ابتدا عکس را انتخاب کنید.');
    try {
      final existingId = attempt['mediaId'] as String?;
      RemoteJson? row;
      if (existingId != null) {
        row = file(
          RemoteJson(await request('GET', '$base/$existingId')).value['file'],
          productId,
          mediaId: existingId,
        );
      }
      if (row?.text('status') == 'READY') return row!.text('mediaId');
      if (bytes != null && row?.text('status') != 'FINALIZING') {
        final reply = RemoteJson(
          await request(
            'POST',
            '$base/uploads',
            body: attempt['body'],
            idempotencyKey: attempt['key'] as String,
          ),
        );
        row = file(reply.value['file'], productId, mediaId: existingId);
        final id = row.text('mediaId');
        attempt['mediaId'] = id;
        await persist(productId, attempt);
        if (row.text('status') == 'READY') return id;
        if (row.text('status') == 'PENDING') {
          final upload = RemoteJson(reply.value['upload']);
          final headers = RemoteJson(upload.value['headers']).value
              .map((k, v) => MapEntry(k, v as String));
          final body = RemoteJson(attempt['body']);
          if (upload.text('method') != 'PUT' ||
              !DateTime.parse(upload.text('expiresAt'))
                  .isAfter(DateTime.now().toUtc()) ||
              headers['Content-Type'] != body.text('contentType') ||
              headers['Content-MD5'] != body.text('checksumMD5') ||
              headers['x-amz-meta-upload-id'] != id ||
              headers.keys.any(
                (k) => ![
                  'Content-Type',
                  'Content-MD5',
                  'x-amz-meta-upload-id',
                ].contains(k),
              )) {
            throw const FormatException('Invalid upload instructions');
          }
          final target = publicUrl(upload.text('url'));
          // This request goes only to the signed storage URL, without API credentials.
          final response =
              await (context.auth.client?.put(
                        target,
                        headers: headers,
                        body: bytes,
                      ) ??
                      http.put(target, headers: headers, body: bytes))
                  .timeout(const Duration(seconds: 45));
          context.check();
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw const AuthError(0, 'MEDIA_UPLOAD_FAILED', retryable: true);
          }
        }
      }
      final id = attempt['mediaId'] as String?;
      if (id == null) {
        throw StateError(
          'برای پیگیری بارگذاری، همان عکس قبلی را دوباره انتخاب کنید.',
        );
      }
      final completed = file(
        RemoteJson(await request('POST', '$base/$id/complete', body: const {}))
            .value['file'],
        productId,
        mediaId: id,
      );
      if (completed.text('status') != 'READY') {
        throw const AuthError(409, 'MEDIA_NOT_READY');
      }
      _urls['$productId:$id'] = Future.value(completed.text('publicUrl'));
      return id;
    } on AuthError catch (failure) {
      if (failure.code == 'UPLOAD_EXPIRED') await clear(productId);
      rethrow;
    }
  }

  static String message(Object failure) {
    if (failure is StateError) return failure.message.toString();
    if (failure is AuthError) {
      switch (failure.code) {
        case 'FORBIDDEN':
          return 'مجوز مشاهده یا بارگذاری عکس این محصول را ندارید.';
        case 'UPLOAD_EXPIRED':
          return 'مهلت بارگذاری تمام شده است؛ عکس را دوباره انتخاب کنید.';
        case 'UPLOAD_NOT_FOUND':
          return 'فایل بارگذاری نشده است؛ همان عکس قبلی را دوباره انتخاب کنید.';
        case 'MEDIA_NOT_READY':
          return 'عکس هنوز آماده نمایش نیست؛ دوباره تلاش کنید.';
        case 'MEDIA_REFERENCE_INVALID':
          return 'عکس باید آماده و متعلق به همین محصول باشد.';
      }
    }
    return 'دریافت یا ثبت عکس انجام نشد؛ دوباره تلاش کنید.';
  }
}
