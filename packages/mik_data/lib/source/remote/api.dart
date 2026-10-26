// ignore_for_file: curly_braces_in_flow_control_structures, avoid_print, empty_catches, library_prefixes

import 'dart:async';
import 'debug_http_client.dart';
import '../../utils/fx/auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_pages/login/components/getData.dart';
import 'package:mik_utils/public/deviceInfo.dart';
import 'package:mik_variables/variable.dart';
import 'package:http/http.dart' as httpClient;

import '../../models/models.dart';
import 'models/auth_session.dart';
import 'auth_error.dart';
import '../../utils/variable.dart';
import 'http.dart' if (dart.library.html) 'httpWeb.dart';

//const url = '10.0.2.2:2333';
const url = 'test.mikcore.ir';

class API {
  static server() async {
    final http = HTTP.io();
    if (internetCheck.isTrue) {
      try {
        var res = await http.get(Uri.https(url, '/'));
        if (res.statusCode == 200) {
          serverAvailable = true;
          print("Server: ${res.body}");
          return true;
        } else {
          serverAvailable = false;
          print("Server Not Alive1");
          Alert.info('دسترسی به سرور مقدور نیست!\nوضیعت اینترنت و خاموش بودن vpn خود را بررسی کنید.');
          return false;
        }
      } on HandshakeException {
        serverAvailable = false;
        Alert.info('دسترسی به سرور مقدور نیست!\nوضیعت اینترنت و خاموش بودن vpn خود را بررسی کنید.');
        print("Server Not Alive2");
        return false;
      } on SocketException {
        serverAvailable = false;
        Alert.info('دسترسی به سرور مقدور نیست!\nوضیعت اینترنت و خاموش بودن vpn خود را بررسی کنید.');
        print("Server Not Alive3");
        return false;
      }
    } else {
      serverAvailable = false;
      return false;
    }
  }

  static checkStatus() async {
    final http = HTTP.io();
    if (internetCheck.isTrue && serverAvailable) {
      var deviceInfo = await DeviceInfo.info();
      String deviceID = deviceInfo['id'];
      try {
        var res = await http
            .get(Uri.https(url, '/v2/status'), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString(), 'deviceID': deviceID, 'appVersion': version})
            .timeout(const Duration(seconds: 5));
        if (!res.body.toString().startsWith('<html>')) {
          return jsonDecode(res.body);
        } else {
          return {};
        }
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  static checkUpdate() async {
    final http = HTTP.io();
    await server();
    if (internetCheck.isTrue && serverAvailable) {
      var res = await http.get(Uri.https(url, '/v2/status/update'), headers: {"Content-Type": "application/json", 'param': 'mikAppReq-startApp-CheckVersion'}).timeout(const Duration(seconds: 5));
      print('UPDATE: ====');
      print(res.body);
      if (!res.body.toString().startsWith('<html>') && !res.body.toString().startsWith('<!DOCTYPE html>')) {
        return jsonDecode(res.body);
      } else {
        return '';
      }
    }
    return '';
  }

  /// Authenticated API entry: refresh and secure session storage belong to AuthFX.
  static Future<Object?> authenticatedRequest(
    AuthFX auth,
    String method,
    String path, {
    Object? data,
    Map<String, String>? query,
    String? idempotencyKey,
  }) => auth.request(method, path, data: data, query: query,
      idempotencyKey: idempotencyKey);

  static Uri get origin {
    final origin = Uri.parse(
      const String.fromEnvironment('API_ORIGIN', defaultValue: 'https://$url'),
    );
    if (!{'http', 'https'}.contains(origin.scheme) ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw ArgumentError('API_ORIGIN must be an HTTP(S) origin');
    }
    return origin;
  }

  static String normalizeDigits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      value = value.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return value.trim();
  }

  static String normalizePhone(String value) {
    final phone = normalizeDigits(value).replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^09\d{9}$').hasMatch(phone)) return '+98${phone.substring(1)}';
    if (phone.startsWith('0098')) return '+${phone.substring(2)}';
    if (phone.startsWith('98')) return '+$phone';
    return phone;
  }

  static Map<String, String> headers({
    String appId = 'mik',
    String? accessToken,
    String? branchId,
    String? idempotencyKey,
  }) {
    if (!{'mik', 'mikyar'}.contains(appId)) throw ArgumentError('Unknown app');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Id': appId,
      'X-App-Version': appId == 'mikyar' ? '1.2.0' : version,
      'X-App-Platform': kIsWeb
          ? 'web'
          : defaultTargetPlatform.name.toLowerCase(),
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      if (branchId != null) 'X-Branch-Id': branchId,
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };
  }

  // Kept for callers using the former authentication-only origin.
  static Uri get authOrigin => origin;

  /// Sends JSON to the gateway. OTP and mutations are never retried here.
  static Future<Object?> request(
    String method,
    String path, {
    Object? data,
    Map<String, String>? query,
    String appId = 'mik',
    String? accessToken,
    String? branchId,
    String? idempotencyKey,
    httpClient.Client? client,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final route = Uri.parse(path);
    if (!path.startsWith('/') ||
        route.hasAuthority ||
        route.hasScheme ||
        route.hasQuery ||
        route.hasFragment) {
      throw ArgumentError('Use a gateway path and pass query separately');
    }
    final verb = method.toUpperCase();
    if (!{'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'}.contains(verb)) {
      throw ArgumentError('Unsupported HTTP method');
    }
    final request = httpClient.Request(
      verb,
      origin.resolve(path).replace(queryParameters: query),
    );
    request.headers.addAll(
      headers(
        appId: appId,
        accessToken: accessToken,
        branchId: branchId,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (data != null) request.body = jsonEncode(data);
    final http = DebugHttpClient(client ?? httpClient.Client());
    try {
      final res = await http
          .send(request)
          .then(httpClient.Response.fromStream)
          .timeout(timeout);
      final success = res.statusCode >= 200 && res.statusCode < 300;
      if (success && (res.statusCode == 204 || verb == 'HEAD')) return null;
      Object? result;
      try {
        result = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        throw AuthError(
          res.statusCode,
          'INVALID_RESPONSE',
          requestId: res.headers['x-request-id'],
        );
      }
      if (!success) {
        final error = result is Map ? result['error'] : null;
        throw AuthError(
          res.statusCode,
          error is Map && error['code'] is String
              ? error['code']
              : 'HTTP_ERROR',
          retryable: error is Map && error['retryable'] == true,
          serverMessage: error is Map && error['message'] is String
              ? error['message'] as String
              : null,
          requestId: res.headers['x-request-id'],
        );
      }
      return result;
    } finally {
      if (client == null) http.close();
    }
  }

  static Future<String> login(
    String act,
    String mobile, {
    String appId = 'mik',
    httpClient.Client? client,
  }) async {
    if (act != 'login' && act != 'reg')
      throw ArgumentError('Invalid authentication action');
    if (appId == 'mikyar' && act == 'reg')
      throw const AuthError(403, 'REGISTRATION_NOT_ALLOWED');
    final phone = normalizePhone(mobile);
    if (!RegExp(r'^\+989\d{9}$').hasMatch(phone))
      throw const AuthError(400, 'PHONE_INVALID');
    final result = await request(
      'POST',
      act == 'reg' ? '/v1/auth/registration/otp' : '/v1/auth/otp',
      data: {'phone': phone},
      appId: appId,
      client: client,
    );
    if (result is! Map || result['accepted'] != true)
      throw const FormatException('Invalid OTP response');
    return '200';
  }

  static Future<String> callToLogin(
    String mobile, {
    String appId = 'mik',
    bool registration = false,
  }) => login(registration ? 'reg' : 'login', mobile, appId: appId);

  static Future<AuthSession> auth(
    Map data, {
    bool registration = false,
    String appId = 'mik',
    httpClient.Client? client,
  }) async {
    if (appId == 'mikyar' && registration)
      throw const AuthError(403, 'REGISTRATION_NOT_ALLOWED');
    final otp = normalizeDigits('${data['otp'] ?? data['code'] ?? ''}');
    final phone = normalizePhone('${data['phone'] ?? data['mobile'] ?? ''}');
    if (!RegExp(r'^\+989\d{9}$').hasMatch(phone))
      throw const AuthError(400, 'PHONE_INVALID');
    if (!RegExp(r'^\d{5}$').hasMatch(otp))
      throw const AuthError(400, 'OTP_LENGTH_INVALID');
    return AuthSession.fromJson(
      await request(
        'POST',
        registration
            ? '/v1/auth/registration/otp/verify'
            : '/v1/auth/otp/verify',
        data: {'phone': phone, 'otp': otp},
        appId: appId,
        client: client,
      ),
    );
  }

  static Future<AuthSession> refreshAuth(
    AuthSession previous, {
    String appId = 'mik',
    httpClient.Client? client,
  }) async {
    final result = await request(
      'POST',
      '/v1/auth/token/refresh',
      data: {'refreshToken': previous.refreshToken},
      appId: appId,
      client: client,
    );
    if (result is! Map ||
        result['accessToken'] is! String ||
        result['accessToken'].isEmpty ||
        result['refreshToken'] is! String ||
        result['refreshToken'].isEmpty ||
        result['accessTokenExpiresInSeconds'] is! int ||
        result['accessTokenExpiresInSeconds'] <= 0) {
      throw const FormatException('Invalid refresh response');
    }
    return AuthSession(
      identityId: previous.identityId,
      sessionId: previous.sessionId,
      accessToken: result['accessToken'],
      refreshToken: result['refreshToken'],
      accessExpiresAt: DateTime.now().toUtc().add(
        Duration(seconds: result['accessTokenExpiresInSeconds']),
      ),
      refreshExpiresAt: previous.refreshExpiresAt,
    );
  }

  static Future<void> logoutAuth(
    String token, {
    String appId = 'mik',
    httpClient.Client? client,
  }) async {
    final result = await request(
      'POST',
      '/v1/auth/logout',
      data: {},
      appId: appId,
      accessToken: token,
      client: client,
    );
    if (result is! Map || result['revoked'] != true)
      throw const FormatException('Invalid logout response');
  }

  static String loginError(Object error, {String appId = 'mik'}) {
    if (error is TimeoutException)
      return 'پاسخ سرور طول کشید. دوباره تلاش کنید.';
    if (error is AuthError) {
      switch (error.code) {
        case 'USER_NOT_FOUND':
          return appId == 'mikyar'
              ? 'حساب کاربری شما در میکیار وجود ندارد.'
              : 'حساب کاربری وجود ندارد.';
        case 'USER_NOT_ACTIVE':
        case 'ACCOUNT_DISABLED':
          return 'حساب کاربری شما غیرفعال است.';
        case 'OTP_WAIT':
          return 'برای ارسال مجدد کد، کمی صبر کنید.';
        case 'INVALID_OTP':
          return 'کد تأیید نامعتبر است یا اعتبار آن تمام شده.';
        case 'OTP_LENGTH_INVALID':
          return 'کد تأیید ۵ رقمی را وارد کنید.';
        case 'PHONE_INVALID':
          return 'شماره موبایل معتبر وارد کنید.';
        case 'OTP_DELIVERY_UNAVAILABLE':
          return 'ارسال پیامک انجام نشد. دوباره تلاش کنید.';
        case 'REFRESH_TOKEN_INVALID':
        case 'SESSION_INVALID':
          return 'نشست شما تمام شده است. دوباره وارد شوید.';
        case 'REGISTRATION_NOT_ALLOWED':
          return 'ثبت‌نام از طریق میکیار امکان‌پذیر نیست.';
      }
      if (error.statusCode == 429)
        return 'درخواست‌های شما زیاد است. کمی بعد دوباره تلاش کنید.';
    }
    return 'ارتباط با سرور انجام نشد. دوباره تلاش کنید.';
  }

  static addFcmToken(item) async {
    //V1 is OK
    return await postAPI(path: '/fcmtoken', data: item);
  }

  static getIMG(type, id, name) async {
    final http = HTTP.io();
    try {
      var filePath = type == 'product' ? '${prImageDir!.path}/$id' : userImageDir!.path;
      if (!await Directory(filePath).exists()) {
        await Directory(filePath).create();
      }
      File file = File('$filePath/$name');
      var res = await http.get(Uri.https(url, '/v2/img/$type/$id/$name'), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()});
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
        return name;
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }

  static getData() async {
    final http = HTTP.io();
    try {
      var res = await http.get(Uri.https(url, '/v2/login/getData'), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()});
      print('GetData');
      if (res.statusCode == 200) {
        if (res.body == '410') {
          return '410';
        } else if (res.body == '411') {
          return '411';
        } else {
          var data = jsonDecode(res.body);
          getDataFirstMaxSize.value = data.toString().length;

          print('--------------------');
          print("----------Profile Data----------");
          if (data['profile'] != null) {
            await profile.clear();
            await getIMG('profile', 0, 'profile.png');
            ProfileDB item = ProfileDB(
              id: data['profile']['id'],
              instagram: data['profile']['instagram'],
              name: data['profile']['name'],
              img: 'profile.png',
              date: data['profile']['date'],
              cardNumber: data['profile']['cardNumber'],
              shebaNumber: data['profile']['shebaNumber'],
              cardNumberName: data['profile']['cardNumberName'],
              province: data['profile']['province'],
              city: data['profile']['city'],
              email: data['profile']['email'],
              tel: data['profile']['tel'],
              site: data['profile']['site'],
              mobile: data['profile']['mobile'],
              slogan: data['profile']['slogan'],
              referral: data['profile']['referral'],
              type: data['profile']['type'],
              nationalID: data['profile']['nationalID'] ?? '',
              economicCode: data['profile']['economicCode'] ?? '',
              postalCode: data['profile']['postalCode'] ?? '',
              stateID: 0,
              townID: 0,
              tspEnabled: data['profile']['tspEnabled'] ?? false,
              backup: 'ok',
            );
            await profile.add(item);
            getDataFirstsavedSize.value += data['profile'].toString().length;
            await person.clear();
            print("person: ${data['person'].length}");
            for (var i = 0; i < data['person'].length; i++) {
              print(data['person'][i]);
              PersonDB prs = PersonDB(
                id: data['person'][i]['id'],
                uid: data['person'][i]['uid'],
                date: data['person'][i]['date'],
                name: data['person'][i]['name'],
                nationalID: data['person'][i]['nationalID'],
                mobile: data['person'][i]['mobile'],
                instagram: data['person'][i]['instagram'],
                email: data['person'][i]['email'],
                cardNumber: data['person'][i]['cardNumber'],
                shebaNumber: data['person'][i]['shebaNumber'],
                address: data['person'][i]['address'],
                isAdmin: data['person'][i]['isAdmin'],
                isSupplier: data['person'][i]['isSupplier'],
                isPartner: data['person'][i]['isPartner'],
                isCustomer: data['person'][i]['isCustomer'],
                isMarketer: data['person'][i]['isMarketer'],
                isService: data['person'][i]['isService'],
                description: data['person'][i]['decription'],
                stateID: data['person'][i]['stateID'],
                townID: data['person'][i]['townID'],
                org: data['person'][i]['org'] ?? false,
                orgName: data['person'][i]['orgName'] ?? '',
                tel: data['person'][i]['tel'] ?? '',
                economicID: data['person'][i]['economicID'] ?? '',
                postalCode: data['person'][i]['postalCode'] ?? '',
                inserter: data['person'][i]['inserter'],
                backup: 'ok',
              );
              await person.add(prs);
              getDataFirstsavedSize.value += data['person'][i].toString().length;
            }
            print('Person add End');
            await category.clear();
            print("categort: ${data['category'].length}");
            for (var i = 0; i < data['category'].length; i++) {
              CategoryDB cat = CategoryDB(
                id: data['category'][i]['id'],
                uid: data['category'][i]['uid'],
                name: data['category'][i]['name'],
                description: data['category'][i]['description'],
                inserter: data['category'][i]['inserter'],
                parent: data['category'][i]['parent'],
                isActive: data['category'][i]['isActive'],
                isCustom: data['category'][i]['isCustom'],
                backup: 'ok',
              );
              await category.add(cat);
              getDataFirstsavedSize.value += data['category'][i].toString().length;
            }

            print('category add End');
            await product.clear();
            print("product: ${data['product'].length}");
            for (var i = 0; i < data['product'].length; i++) {
              List<String> prdIMG = [];
              for (var g = 0; g < data['product'][i]['img'].length; g++) {
                prdIMG.add(await getIMG('product', data['product'][i]['id'], data['product'][i]['img'][g]));
              }
              ProductDB prd = ProductDB(
                id: data['product'][i]['id'],
                uid: data['product'][i]['uid'],
                taxID: data['product'][i]['taxID'],
                name: data['product'][i]['name'],
                img: data['product'][i]['img'], //data['product'][i]['img'],
                archive: data['product'][i]['archive'] ?? false,
                categoryID: data['product'][i]['categoryID'],
                barcode: data['product'][i]['barcode'],
                description: data['product'][i]['description'],
                sellPrice: data['product'][i]['sellPrice'],
                commission: double.tryParse((data['product'][i]['commission']).toString()) ?? 0,
                isCommissionFixed: data['product'][i]['isCommissionFixed'],
                date: data['product'][i]['date'],
                inventory: double.tryParse(data['product'][i]['inventory'].toString()) ?? 0.0,
                inventoryControl: data['product'][i]['inventoryControl'],
                type: data['product'][i]['type'] ?? 'product',
                vat: double.tryParse(data['product'][i]['vat'].toString()) ?? 0.0,
                sellPriceList: [],
                // data['product'][i]['sellPriceList'] == null || data['product'][i]['sellPriceList'].isEmpty
                //     ? <int>[data['product'][i]['sellPrice']]
                //     : List<int>.from(data['product'][i]['sellPriceList']),
                catIDList: data['product'][i]['catIDList'] == null || data['product'][i]['catIDList'].isEmpty
                    ? <String>[data['product'][i]['categoryID'].toString()]
                    : List<String>.from(data['product'][i]['catIDList']),
                unitCode: data['product'][i]['unitCode'] ?? 0,
                inserter: data['product'][i]['inserter'],
                backup: 'ok',
              );
              getDataFirstsavedSize.value += data['product'][i].toString().length;
              await product.add(prd);
            }
            print('product add End');

            await productProperty.clear();
            print("productProperty: ${data['productProperty'].length}");
            for (var i = 0; i < data['productProperty'].length; i++) {
              ProductPropertyDB prd = ProductPropertyDB(
                uid: data['productProperty'][i]['uid'],
                name: data['productProperty'][i]['name'],
                type: data['productProperty'][i]['type'],
                value: data['productProperty'][i]['value'] ?? [],
                inserter: data['productProperty'][i]['inserter'],
                backup: 'ok',
              );
              getDataFirstsavedSize.value += data['productProperty'][i].toString().length;
              await productProperty.add(prd);
            }
            print('productProperty add End');

            await productPro.clear();
            print("productPro: ${data['productPro'].length}");
            for (var i = 0; i < data['productPro'].length; i++) {
              ProductProDB prd = ProductProDB(
                uid: data['productPro'][i]['uid'],
                productUID: data['productPro'][i]['productUID'],
                property: List.from(data['productPro'][i]['property']),
                desc: data['productPro'][i]['desc'],
                inserter: data['productPro'][i]['inserter'],
                backup: 'ok',
              );
              getDataFirstsavedSize.value += data['productPro'][i].toString().length;
              await productPro.add(prd);
            }
            print('productPro add End');

            await productPrice.clear();
            print("productPrice: ${data['productPrice'].length}");
            for (var i = 0; i < data['productPrice'].length; i++) {
              ProductPriceDB prd = ProductPriceDB(
                uid: data['productPrice'][i]['uid'],
                puid: data['productPrice'][i]['puid'],
                pro: data['productPrice'][i]['pro'],
                price: data['productPrice'][i]['price'],
                name: data['productPrice'][i]['name'],
                defaultPrice: data['productPrice'][i]['defaultPrice'],
                dateValid: data['productPrice'][i]['dateValid'],
                inserter: data['productPrice'][i]['inserter'],
                backup: 'ok',
              );
              getDataFirstsavedSize.value += data['productPrice'][i].toString().length;
              await productPrice.add(prd);
            }
            print('productPrice add End');

            print("warehouse: ${data['warehouse'].length}");
            await warehouse.clear();
            for (var i = 0; i < data['warehouse'].length; i++) {
              WarehouseDB wr = WarehouseDB(
                id: data['warehouse'][i]['id'],
                uid: data['warehouse'][i]['uid'],
                wuid: data['warehouse'][i]['wuid'],
                puid: data['warehouse'][i]['puid'],
                prouid: data['warehouse'][i]['prouid'] ?? '-',
                inserter: data['warehouse'][i]['inserter'],
                inventory: double.parse(data['warehouse'][i]['inventory'].toString()),
                backup: 'ok',
              );
              await warehouse.add(wr);
            }
            print('warehouse add End');
            print("warehouseName: ${data['warehouseName'].length}");
            await warehouseName.clear();
            for (var i = 0; i < data['warehouseName'].length; i++) {
              WarehouseNameDB wr = WarehouseNameDB(
                id: data['warehouseName'][i]['id'],
                uid: data['warehouseName'][i]['uid'],
                name: data['warehouseName'][i]['name'],
                active: data['warehouseName'][i]['active'],
                inserter: data['warehouseName'][i]['inserter'],
                backup: 'ok',
              );
              await warehouseName.add(wr);
            }
            print('warehouseName add End');
            print("warehouseHistory: ${data['warehouseHistory'].length}");
            await warehouseHistory.clear();
            for (var i = 0; i < data['warehouseHistory'].length; i++) {
              WarehouseHistoryDB wr = WarehouseHistoryDB(
                id: data['warehouseHistory'][i]['id'],
                uid: data['warehouseHistory'][i]['uid'],
                parentuid: data['warehouseHistory'][i]['parentuid'],
                from: data['warehouseHistory'][i]['from'],
                to: data['warehouseHistory'][i]['to'],
                date: data['warehouseHistory'][i]['date'],
                by: data['warehouseHistory'][i]['by'],
                type: data['warehouseHistory'][i]['type'],
                puid: data['warehouseHistory'][i]['puid'],
                prouid: data['warehouseHistory'][i]['prouid'] ?? '',
                inserter: data['warehouseHistory'][i]['inserter'],
                amount: double.parse(data['warehouseHistory'][i]['amount'].toString()),
                backup: 'ok',
              );
              await warehouseHistory.add(wr);
            }
            print('warehouseHistory add End');
            await partnerTransaction.clear();
            print("partnerTransaction: ${data['partnerTransaction'].length}");
            for (var i = 0; i < data['partnerTransaction'].length; i++) {
              PartnerTransactionDB ins = PartnerTransactionDB(
                id: data['partnerTransaction'][i]['id'],
                uid: data['partnerTransaction'][i]['uid'],
                partnerID: data['partnerTransaction'][i]['partnerID'],
                partnerUID: data['partnerTransaction'][i]['partnerUID'],
                amount: data['partnerTransaction'][i]['amount'],
                status: data['partnerTransaction'][i]['status'],
                date: data['partnerTransaction'][i]['date'],
                inserter: data['partnerTransaction'][i]['inserter'],
                backup: 'ok',
              );
              await partnerTransaction.add(ins);
            }
            print('partnerTransaction add End');

            await commission.clear();
            print("Commission: ${data['commission'].length}");
            for (var i = 0; i < data['commission'].length; i++) {
              CommissionDB cms = CommissionDB(
                id: data['commission'][i]['id'],
                uid: data['commission'][i]['uid'],
                personID: data['commission'][i]['personID'],
                factorID: data['commission'][i]['factorID'],
                //  personUID: data['commission'][i]['personUID'],
                factorUID: data['commission'][i]['factorUID'],
                amount: data['commission'][i]['amount'],
                type: data['commission'][i]['type'],
                description: data['commission'][i]['description'],
                date: data['commission'][i]['date'],
                inserter: data['commission'][i]['inserter'],
                backup: 'ok',
              );
              await commission.add(cms);
              getDataFirstsavedSize.value += data['commission'][i].toString().length;
            }
            print('Commission add End');
            await invoice.clear();
            print("Invoice: ${data['invoice'].length}");
            for (var i = 0; i < data['invoice'].length; i++) {
              InvoiceDB inv = InvoiceDB(
                id: data['invoice'][i]['id'] ?? 0,
                uid: data['invoice'][i]['uid'],
                personUID: data['invoice'][i]['personUID'],
                branchUID: data['invoice'][i]['branchUID'],
                items: data['invoice'][i]['items'],
                billUID: List<String>.from(data['invoice'][i]['billUID']),
                date: data['invoice'][i]['date'],
                doc: data['invoice'][i]['doc'],
                parameters: data['invoice'][i]['parameters'],
                type: data['invoice'][i]['type'],
                shipping: data['invoice'][i]['shipping'],
                status: data['invoice'][i]['status'],
                commission: data['invoice'][i]['commission'],
                inserter: data['invoice'][i]['inserter'],
                description: data['invoice'][i]['description'],
                backup: 'ok',
              );
              await invoice.add(inv);
              getDataFirstsavedSize.value += data['invoice'][i].toString().length;
            }
            print('Invoice add End');
            if (data['invoice'] == null || (data['invoice'] != null && data['invoice'].isEmpty)) {
              await factor.clear();
              print("Factor: ${data['factor'].length}");
              //Add Invoice
              for (var i = 0; i < data['factor'].length; i++) {
                FactorDB fct = FactorDB(
                  id: data['factor'][i]['id'],
                  productID: List<int>.from(data['factor'][i]['productID']),
                  productUID: List<String>.from(data['factor'][i]['productUID']),
                  amount: data['factor'][i]['amount'],
                  buyPrice: data['factor'][i]['buyPrice'],
                  sellPrice: data['factor'][i]['sellPrice'],
                  personID: data['factor'][i]['personID'],
                  personUID: data['factor'][i]['personUID'],
                  doc: data['factor'][i]['doc'],
                  isBuy: data['factor'][i]['isBuy'],
                  excess: data['factor'][i]['excess'],
                  shippingCost: data['factor'][i]['shippingCost'],
                  status: data['factor'][i]['status'],
                  statusDate: data['factor'][i]['statusDate'],
                  editDate: data['factor'][i]['editDate'],
                  commission: data['factor'][i]['commission'],
                  cRecipient: data['factor'][i]['cRecipient'],
                  cRecipientUID: data['factor'][i]['cRecipientUID'],
                  cStatus: data['factor'][i]['cStatus'],
                  discount: data['factor'][i]['discount'],
                  isDiscountFixed: data['factor'][i]['isDiscountFixed'],
                  description: data['factor'][i]['description'],
                  date: data['factor'][i]['date'],
                  billID: data['factor'][i]['billID'],
                  billUID: List<String>.from(data['factor'][i]['billUID']),
                  uuid: data['factor'][i]['uuid'],
                  type: data['factor'][i]['type'],
                  vat: data['factor'][i]['vat'],
                  vatCalculated: data['factor'][i]['vatCalculated'],
                  inserter: data['factor'][i]['inserter'],
                  backup: 'ok',
                );
                await factor.add(fct);
                getDataFirstsavedSize.value += data['factor'][i].toString().length;
              }
              print('Factor add End');
            }
            await costCategory.clear();
            for (var i = 0; i < data['costCategory'].length; i++) {
              CostCategoryDB item = CostCategoryDB(
                id: data['costCategory'][i]['id'],
                uid: data['costCategory'][i]['uid'],
                name: data['costCategory'][i]['name'],
                description: data['costCategory'][i]['description'],
                inserter: data['costCategory'][i]['inserter'],
                backup: 'ok',
              );
              await costCategory.add(item);
              getDataFirstsavedSize.value += data['costCategory'][i].toString().length;
            }
            print('costCategory add End');

            await cost.clear();
            for (var i = 0; i < data['cost'].length; i++) {
              CostDB item = CostDB(
                id: data['cost'][i]['id'],
                uid: data['cost'][i]['uid'],
                categoryID: data['cost'][i]['categoryID'],
                categoryUID: data['cost'][i]['categoryUID'],
                name: data['cost'][i]['name'],
                description: data['cost'][i]['description'],
                price: data['cost'][i]['price'],
                factorID: data['cost'][i]['factorID'],
                factorUID: data['cost'][i]['factorUID'],
                personID: data['cost'][i]['personID'],
                personUID: data['cost'][i]['personUID'],
                date: data['cost'][i]['date'],
                billID: data['cost'][i]['billID'],
                billUID: data['cost'][i]['billUID'],
                inserter: data['cost'][i]['inserter'],
                backup: 'ok',
              );
              await cost.add(item);
              getDataFirstsavedSize.value += data['cost'][i].toString().length;
            }
            print('cost add End');

            await bill.clear();
            for (var i = 0; i < data['bill'].length; i++) {
              BillDB item = BillDB(
                id: data['bill'][i]['id'],
                uid: data['bill'][i]['uid'],
                debtor: data['bill'][i]['debtor'],
                creditor: data['bill'][i]['creditor'],
                debtorUID: data['bill'][i]['debtorUID'],
                creditorUID: data['bill'][i]['creditorUID'],
                total: data['bill'][i]['total'],
                paid: data['bill'][i]['paid'],
                unPaid: data['bill'][i]['unPaid'],
                to: data['bill'][i]['to'],
                toUID: data['bill'][i]['toUID'],
                date: data['bill'][i]['date'],
                deadLine: data['bill'][i]['deadLine'],
                type: data['bill'][i]['type'],
                inserter: data['bill'][i]['inserter'],
                meta: data['bill'][i]['meta'],
                backup: 'ok',
              );
              await bill.add(item);
              getDataFirstsavedSize.value += data['bill'][i].toString().length;
            }
            print('bill add End');

            await cheque.clear();
            for (var i = 0; i < data['cheque'].length; i++) {
              ChequeDB ch = ChequeDB(
                id: data['cheque'][i]['id'],
                uid: data['cheque'][i]['uid'],
                billID: data['cheque'][i]['billID'],
                billUID: data['cheque'][i]['billUID'],
                accNo: data['cheque'][i]['accNo'],
                bankID: data['cheque'][i]['bankID'],
                branch: data['cheque'][i]['branch'],
                branchNo: data['cheque'][i]['branchNo'],
                chequeNo: data['cheque'][i]['chequeNo'],
                date: data['cheque'][i]['date'],
                desc: data['cheque'][i]['desc'],
                dueDate: data['cheque'][i]['dueDate'],
                holder: data['cheque'][i]['holder'],
                payee: data['cheque'][i]['payee'],
                holderUID: data['cheque'][i]['holderUID'],
                payeeUID: data['cheque'][i]['payeeUID'],
                price: data['cheque'][i]['price'],
                status: data['cheque'][i]['status'],
                to: data['cheque'][i]['to'],
                toUID: data['cheque'][i]['toUID'],
                inserter: data['cheque'][i]['inserter'],
                backup: 'ok',
              );
              await cheque.add(ch);
              getDataFirstsavedSize.value += data['cheque'][i].toString().length;
            }
            print('cheque add End');

            await connection.clear();
            try {
              for (var i = 0; i < data['connection'].length; i++) {
                ConnectionDB ch = ConnectionDB(
                  id: data['connection'][i]['id'],
                  uid: data['connection'][i]['uid'],
                  by: data['connection'][i]['by'],
                  date: data['connection'][i]['date'],
                  desc: data['connection'][i]['desc'],
                  personUID: data['connection'][i]['personUID'],
                  result: data['connection'][i]['result'],
                  status: data['connection'][i]['status'],
                  nextDate: data['connection'][i]['nextDate'],
                  parent: data['connection'][i]['parent'],
                  inserter: data['connection'][i]['inserter'],
                  backup: 'ok',
                );
                await connection.add(ch);
                getDataFirstsavedSize.value += data['connection'][i].toString().length;
              }
            } catch (e) {}
            print('connection add End');

            await mikyar.clear();
            try {
              for (var i = 0; i < data['mikyar'].length; i++) {
                MiKYarDB ch = MiKYarDB(
                  id: data['mikyar'][i]['id'],
                  mobile: data['mikyar'][i]['mobile'],
                  name: data['mikyar'][i]['name'],
                  post: data['mikyar'][i]['post'],
                  permission: data['mikyar'][i]['permission'],
                  permissionUID: data['mikyar'][i]['permissionUID'],
                  inserter: data['mikyar'][i]['inserter'],
                  active: data['mikyar'][i]['active'],
                  backup: 'ok',
                );
                await mikyar.add(ch);
                getDataFirstsavedSize.value += data['mikyar'][i].toString().length;
              }
            } catch (e) {}
            print('MikYar add End');

            await mikyarPermission.clear();
            try {
              for (var i = 0; i < data['mikyarPermission'].length; i++) {
                MiKYarPermissionDB ch = MiKYarPermissionDB(
                  id: data['mikyarPermission'][i]['id'],
                  uid: data['mikyarPermission'][i]['uid'],
                  name: data['mikyarPermission'][i]['name'],
                  permission: data['mikyarPermission'][i]['permission'],
                  inserter: data['mikyarPermission'][i]['inserter'],
                  backup: 'ok',
                );
                await mikyarPermission.add(ch);
                getDataFirstsavedSize.value += data['mikyarPermission'][i].toString().length;
              }
            } catch (e) {}
            print('mikyarPermission add End');

            await mikyarPermissionExt.clear();
            try {
              for (var i = 0; i < data['mikyarPermissionExt'].length; i++) {
                MiKYarPermissionExtDB ch = MiKYarPermissionExtDB(
                  id: data['mikyarPermissionExt'][i]['id'],
                  uid: data['mikyarPermissionExt'][i]['uid'],
                  yarID: data['mikyarPermissionExt'][i]['yarID'],
                  branch: List<String>.from(data['mikyarPermissionExt'][i]['branch']),
                  warehouse: List<String>.from(data['mikyarPermissionExt'][i]['warehouse']),
                  inserter: data['mikyarPermissionExt'][i]['inserter'],
                  backup: 'ok',
                );
                await mikyarPermissionExt.add(ch);
                getDataFirstsavedSize.value += data['mikyarPermissionExt'][i].toString().length;
              }
            } catch (e) {}
            print('mikyarPermissionExt add End');

            await branch.clear();
            try {
              for (var i = 0; i < data['branch'].length; i++) {
                BranchDB ch = BranchDB(
                  id: data['branch'][i]['id'],
                  uid: data['branch'][i]['uid'],
                  name: data['branch'][i]['name'],
                  active: data['branch'][i]['active'],
                  description: data['branch'][i]['description'],
                  address: data['branch'][i]['address'],
                  location: data['branch'][i]['location'],
                  inserter: data['branch'][i]['inserter'],
                  defaultWarehouse: data['branch'][i]['defaultWarehouse'],
                  backup: 'ok',
                );
                await branch.add(ch);
                getDataFirstsavedSize.value += data['branch'][i].toString().length;
              }
            } catch (e) {}
            print('branch add End');

            await branchAccess.clear();
            try {
              for (var i = 0; i < data['branchAccess'].length; i++) {
                BranchAccessDB ch = BranchAccessDB(
                  id: data['branchAccess'][i]['id'],
                  uid: data['branchAccess'][i]['uid'],
                  branchUID: data['branchAccess'][i]['branchUID'],
                  warehouseUID: List<String>.from(data['branchAccess'][i]['warehouseUID']),
                  inserter: data['branchAccess'][i]['inserter'],
                  backup: 'ok',
                );
                await branchAccess.add(ch);
                getDataFirstsavedSize.value += data['branchAccess'][i].toString().length;
              }
            } catch (e) {}
            print('branch add End');

            await financialPeriod.clear();
            if (data['financialPeriod'] != null) {
              for (var i = 0; i < data['financialPeriod'].length; i++) {
                FinancialPeriod fnp = FinancialPeriod(
                  id: data['financialPeriod'][i]['id'],
                  uid: data['financialPeriod'][i]['uid'],
                  startDate: data['financialPeriod'][i]['startDate'],
                  endDate: data['financialPeriod'][i]['endDate'],
                  partnerID: data['financialPeriod'][i]['partnerID'],
                  percentage: data['financialPeriod'][i]['percentage'],
                  profit: data['financialPeriod'][i]['profit'],
                  date: data['financialPeriod'][i]['date'],
                  inserter: data['financialPeriod'][i]['inserter'],
                  backup: 'ok',
                );
                await financialPeriod.add(fnp);
              }
            }
            print('fonancialPeriod add end');

            if (data['settings'] != null) {
              await settingsData.clear();
              print(data['settings']);
              SendSmsSetting smsSet = SendSmsSetting(
                orderSubmit: data['settings']['sendSms']['orderSubmit'],
                orderSended: data['settings']['sendSms']['orderSended'],
                orderReadySend: data['settings']['sendSms']['orderReadySend'],
                orderDelayTanks: data['settings']['sendSms']['orderDelayTanks'],
                orderCancelled: data['settings']['sendSms']['orderCancelled'],
                orderReturned: data['settings']['sendSms']['orderReturned'],
                preFactor: data['settings']['sendSms']['preFactor'],
              );
              SettingsData setting = SettingsData(
                darkMode: data['settings']['darkMode'],
                dayForCancel: data['settings']['dayForCancel'],
                animation: data['settings']['animation'],
                factorType: data['settings']['factorType'],
                factorText: data['settings']['factorText'],
                factorColor1: data['settings']['factorColor1'],
                factorColor2: data['settings']['factorColor2'],
                dayForPreFactor: data['settings']['dayForPreFactor'],
                usePreFactor: data['settings']['usePreFactor'],
                sendSms: smsSet,
                skipInit: false,
                factorLink: data['settings']['factorLink'],
                factorVat: data['settings']['factorVat'],
                factorSize: data['settings']['factorSize'],
                factorIsRial: data['settings']['factorIsRial'],
                connectionStatus: List<String>.from(data['settings']['connectionStatus']),
                profitInInvoice: data['settings']['profitInInvoice'],
                backup: 'ok',
              );
              await settingsData.add(setting);
              getDataFirstsavedSize.value += data['settings'].toString().length;
            }
            print('settingData add end');
            if (data['smsPattern'] != null) {
              await pattern.clear();
              for (var i = 0; i < data['smsPattern'].length; i++) {
                PatternDB pt = PatternDB(
                  code: data['smsPattern'][i]['code'],
                  orderType: data['smsPattern'][i]['orderType'],
                  text: data['smsPattern'][i]['text'],
                  pattern: data['smsPattern'][i]['pattern'],
                  status: data['smsPattern'][i]['status'],
                  active: data['smsPattern'][i]['active'],
                  inserter: data['smsPattern'][i]['inserter'],
                  backup: 'ok',
                );
                await pattern.add(pt);
                getDataFirstsavedSize.value += data['smsPattern'][i].toString().length;
              }
            }
            print('smsPatteren add end');
            if (data['sms'] != null) {
              await sms.clear();
              for (var i = 0; i < data['sms'].length; i++) {
                SmsPatternValue spv = SmsPatternValue(
                  date: data['sms'][i]['patternValue']['date'],
                  factorID: data['sms'][i]['patternValue']['factorID'].toString(),
                  link: data['sms'][i]['patternValue']['link'],
                  name: data['sms'][i]['patternValue']['name'],
                  price: data['sms'][i]['patternValue']['price'].toString(),
                );
                SMS s = SMS(
                  personID: data['sms'][i]['personID'],
                  patternCode: data['sms'][i]['patternCode'],
                  smsPatternValue: spv,
                  mobile: data['sms'][i]['mobile'],
                  status: data['sms'][i]['status'],
                  bulk: data['sms'][i]['bulk'],
                  inserter: data['sms'][i]['inserter'],
                  date: data['sms'][i]['date'],
                );
                await sms.add(s);
                getDataFirstsavedSize.value += data['sms'][i].toString().length;
              }
            }
            print('sms add end');
            try {
              var l = localSetting.getAt(0)!;
              l.init = false;
              await localSetting.putAt(0, l);
            } catch (e) {
              // localSetting.add(LocalSetting(firstInvoice: firstInvoice, firstDebt: firstDebt, firstCreadit: firstCreadit, firstInvest: firstInvest, homeChartType: homeChartType, fastReportDayRang: fastReportDayRang))
            }

            //all DATA GET
            // Get.offAll(() => App());
          } else {
            return '400';
          }
          return '200';
        }
      }
    } catch (e) {
      print("ERR: $e");
      return '400';
    }
  }

  // static getStatusSummary() async {
  //   return getAPI(path: '/v2/status/summary');
  // }

  static getSession() async {
    final http = HTTP.io();
    //V1 is OK
    try {
      var res = await http.get(Uri.https(url, '/session'), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()});
      print('GetData');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      return [];
    }
  }

  static deleteSession(item) async {
    final http = HTTP.io();
    //V1 is OK
    try {
      var res = await http.delete(Uri.https(url, '/session'), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()}, body: jsonEncode(item));
      if (res.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static getFildinReg() async {
    return await getAPI(path: '/v2/register/fild');
  }

  static register(reg) async {
    return await postAPI(path: '/v2/register', data: reg);
    // if (serverAvailable) {
    //   print('send data');
    //   var request = http.MultipartRequest('POST', Uri.https(url, '/register'));
    //   if (img != null) {
    //     request.files.add(await http.MultipartFile.fromPath(
    //       'picture',
    //       img,
    //     ));
    //   }
    //   request.headers['auth-token'] = jwt.getAt(0)!.token.toString();
    //   request.fields.addAll(reg);
    //   var res = await DebugHttpClient.sendRequest(request);
    //   var responseData = await res.stream.toBytes();
    //   var result = String.fromCharCodes(responseData);
    //   print(result);
    //   return result;

    //   // return await postAPI(
    //   //     path: '/register', data: {'reg': reg, 'deviceinfo': deviceinfo});
    // } else {
    //   if (internetCheck.isFalse)
    //     return 'net';
    //   else if (!serverAvailable) return 'server';
    // }
  }

  static getCat() async {
    return await getAPI(path: '/v2/product/initcat');
  }

  static updateProfile(item) async {
    return await postAPI(path: '/v2/profile', data: item);
  }

  // static updateProfilePic(img, imgString) async {
  //   try {
  //     var request =
  //         http.MultipartRequest('POST', Uri.https(url, '/v2/profile/pic'));
  //     request.files.add(await http.MultipartFile.fromPath(
  //       'picture',
  //       img,
  //     ));
  //     request.headers['auth-token'] = jwt.getAt(0)!.token.toString();
  //     var res = await DebugHttpClient.sendRequest(request);
  //     var responseData = await res.stream.toBytes();
  //     var result = String.fromCharCodes(responseData);
  //     if (result.toString() != '200') {
  //       await saveDataQueue({
  //         'data': {'id': 'prf'},
  //         'img': imgString
  //       }, '/profileUpdate/pic');
  //     }
  //     return result.toString();
  //   } catch (e) {
  //     await saveDataQueue({
  //       'data': {'id': 'prf'},
  //       'img': imgString
  //     }, '/profileUpdate/pic');
  //   }
  // }
  static getSMS() {
    return getAPI(path: '/v2/mikway/sms/history');
  }

  static getMikYar() async {
    return getAPI(path: '/v2/mikway/yar');
  }

  static addMikYarAuth(item) async {
    return await postAPI(path: '/v2/mikway/yar/auth', data: item);
  }

  static addMikYarAuthConf(item) async {
    return await postAPI(path: '/v2/mikway/yar/authConf', data: item);
  }

  static addMikYarAuthCall(item) async {
    return await postAPI(path: '/v2/mikway/yar/call', data: item);
  }

  static addMikYar(item) async {
    return await postAPI(path: '/v2/mikway/yar', data: item);
  }

  static editMikYar(item) async {
    return putAPI(path: '/v2/mikway/yar', data: item);
  }

  static delMikYar(item) async {
    return deleteAPI(path: '/v2/mikway/yar', data: item);
  }

  static getMikYarPermission() async {
    return getAPI(path: '/v2/mikway/yar/permission');
  }

  static addMikYarPermission(item) async {
    return await postAPI(path: '/v2/mikway/yar/permission', data: item);
  }

  static editMikYarPermission(item) async {
    return putAPI(path: '/v2/mikway/yar/permission', data: item);
  }

  static delMikYarPermission(item) async {
    return deleteAPI(path: '/v2/mikway/yar/permission', data: item);
  }

  static getMikYarPermissionExt() async {
    return getAPI(path: '/v2/mikway/yar/permissionext');
  }

  static addMikYarPermissionExt(item) async {
    return await postAPI(path: '/v2/mikway/yar/permissionext', data: item);
  }

  static editMikYarPermissionExt(item) async {
    return putAPI(path: '/v2/mikway/yar/permissionext', data: item);
  }

  static delMikYarPermissionExt(item) async {
    return deleteAPI(path: '/v2/mikway/yar/permissionext', data: item);
  }

  static addPerson(item) async {
    return await postAPI(path: '/v2/person', data: item);
  }

  static editPerson(item) async {
    return await postAPI(path: '/v2/person/edit', data: item);
  }

  static addPartnerTransaction(item) async {
    return await postAPI(path: '/v2/partnerTransaction', data: item);
  }

  static delPartnerTransaction(item) async {
    return await postAPI(path: '/v2/partnerTransaction/del', data: item);
  }

  static addNewFild(item) async {
    return await postAPI(path: '/v2/product/category/newfild', data: item);
  }

  static addCategory(item) async {
    return await postAPI(path: '/v2/product/category', data: item);
  }

  static editCategory(item) async {
    return await postAPI(path: '/v2/product/category/edit', data: item);
  }

  static delCategory(item) async {
    return await postAPI(path: '/v2/product/category/del', data: item);
  }

  static addProduct(item) async {
    return await postAPI(path: '/v2/product/add', data: item);
  }

  static editProduct(item) async {
    return await postAPI(path: '/v2/product/edit', data: item);
  }

  static delProduct(item) async {
    return await postAPI(path: '/v2/product/del', data: item);
  }

  static addProductProperty(item) async {
    return await postAPI(path: '/v2/product/property/add', data: item);
  }

  static editProductProperty(item) async {
    return await postAPI(path: '/v2/product/property/edit', data: item);
  }

  static delProductProperty(item) async {
    return await postAPI(path: '/v2/product/property/del', data: item);
  }

  static addProductPro(item) async {
    return await postAPI(path: '/v2/product/pro/add', data: item);
  }

  static editProductPro(item) async {
    return await postAPI(path: '/v2/product/pro/edit', data: item);
  }

  static delProductPro(item) async {
    return await postAPI(path: '/v2/product/pro/del', data: item);
  }

  static addProductPrice(item) async {
    return await postAPI(path: '/v2/product/price/add', data: item);
  }

  static editProductPrice(item) async {
    return await postAPI(path: '/v2/product/price/edit', data: item);
  }

  static delProductPrice(item) async {
    return await postAPI(path: '/v2/product/price/del', data: item);
  }

  static addBranch(item) async {
    return await postAPI(path: '/v2/mikway/branch/add', data: item);
  }

  static editBranch(item) async {
    return await postAPI(path: '/v2/mikway/branch/edit', data: item);
  }

  static delBranch(item) async {
    return await postAPI(path: '/v2/mikway/branch/del', data: item);
  }

  static addBranchAccess(item) async {
    return await postAPI(path: '/v2/mikway/branch/access/add', data: item);
  }

  static editBranchAccess(item) async {
    return await postAPI(path: '/v2/mikway/branch/access/edit', data: item);
  }

  static delBranchAccess(item) async {
    return await postAPI(path: '/v2/mikway/branch/access/del', data: item);
  }

  static addWarehouse(item) async {
    return await postAPI(path: '/v2/warehouse/tr/add', data: item);
  }

  static editWarehouse(item) async {
    return await postAPI(path: '/v2/warehouse/tr/edit', data: item);
  }

  static delWarehouse(item) async {
    return await postAPI(path: '/v2/warehouse/tr/del', data: item);
  }

  static addWarehouseName(item) async {
    return await postAPI(path: '/v2/warehouse/add', data: item);
  }

  static editWarehouseName(item) async {
    return await postAPI(path: '/v2/warehouse/edit', data: item);
  }

  static delWarehouseName(item) async {
    return await postAPI(path: '/v2/warehouse/del', data: item);
  }

  static addWarehouseHistory(item) async {
    return await postAPI(path: '/v2/warehouse/history/add', data: item);
  }

  static editWarehouseHistory(item) async {
    return await postAPI(path: '/v2/warehouse/history/edit', data: item);
  }

  static delWarehouseHistory(item) async {
    return await postAPI(path: '/v2/warehouse/history/del', data: item);
  }

  static warehouseTransfer(data) async {
    return await postAPI(path: '/v2/warehouse/transfer', data: data);
  }

  static addInvoice(item) async {
    return await postAPI(path: '/v2/invoice', data: item);
  }

  // static editInvoice(item) async {
  //   return await postAPI(path: '/v2/invoice/edit', data: item);
  // }

  static delInvoice(item) async {
    return await postAPI(path: '/v2/invoice/del', data: item);
  }

  static addCommission(item) async {
    return await postAPI(path: '/v2/commission', data: item);
  }

  static editCommission(item) async {
    return await postAPI(path: '/v2/commission/edit', data: item);
  }

  static addCost(item) async {
    return await postAPI(path: '/v2/cost/add', data: item);
  }

  static editCost(item) async {
    return await postAPI(path: '/v2/cost/edit', data: item);
  }

  static delCost(item) async {
    return await postAPI(path: '/v2/cost/del', data: item);
  }

  static addCostCategory(item) async {
    return await postAPI(path: '/v2/cost/category', data: item);
  }

  static editCostCategory(item) async {
    return await postAPI(path: '/v2/cost/category/edit', data: item);
  }

  static delCostCategory(item) async {
    return await postAPI(path: '/v2/cost/category/del', data: item);
  }

  static setting(item) async {
    return await postAPI(path: '/v2/setting', data: item);
  }

  static addBill(item) async {
    return await postAPI(path: '/v2/bill', data: item);
  }

  static editBill(item) async {
    return await postAPI(path: '/v2/bill/edit', data: item);
  }

  static delBill(item) async {
    return await postAPI(path: '/v2/bill/del', data: item);
  }

  static editBillID(item, id) {
    return putAPI(path: '/v2/bill/edit/$id', data: item);
  }

  static addCheque(item) async {
    return await postAPI(path: '/v2/cheque', data: item);
  }

  static editCheque(item) async {
    return await postAPI(path: '/v2/cheque/edit', data: item);
  }

  static delCheque(item) async {
    return await postAPI(path: '/v2/cheque/del', data: item);
  }

  static addfinancialPeriod(item) async {
    return await postAPI(path: '/v2/financialPeriod', data: item);
  }

  static getPKG() {
    return getAPI(path: '/v2/accpkg');
  }

  static getPKGHistory() {
    return getAPI(path: '/v2/accpkg/history');
  }

  static chargePKG(data) async {
    return await postAPI(path: '/v2/accpkg/charge', data: data);
  }

  static submitMarketAcc(data) async {
    return await postAPI(path: '/v2/accpkg/market', data: data);
  }

  static checkDiscount(data) async {
    return await postAPI(path: '/v2/dgc/status', data: data);
  }

  static giftCard(data) async {
    return await postAPI(path: '/v2/dgc/gift', data: data);
  }

  // static reqIPG(data, zip, fileName) async {
  //   // return await postAPI(path: '/ipg', data: data);
  //   try {
  //     var request = http.MultipartRequest('POST', Uri.https(url, '/v2/ipg'));
  //     request.files.add(
  //         await http.MultipartFile.fromPath('file', zip, filename: fileName));
  //     request.headers['auth-token'] = jwt.getAt(0)!.token.toString();
  //     request.fields.addAll(data);
  //     var res = await DebugHttpClient.sendRequest(request);
  //     var responseData = await res.stream.toBytes();
  //     var result = String.fromCharCodes(responseData);
  //     return result.toString();
  //   } catch (e) {}
  // }

  static reqNewIPG(data, file) async {
    // final http = HTTP.io();
    try {
      // var request =
      //     http.MultipartRequest('POST', Uri.https(url, '/v2/mikway/ipgreq'));
      var request = httpClient.MultipartRequest("POST", Uri.https(url, '/v2/mikway/ipgreq'));
      request.files.add(await httpClient.MultipartFile.fromPath('picture', file));
      request.headers['auth-token'] = jwt.getAt(0)!.token.toString();
      request.fields.addAll(data);
      var res = await DebugHttpClient.sendRequest(request);
      var responseData = await res.stream.toBytes();
      var result = String.fromCharCodes(responseData);
      return result.toString();
    } catch (e) {}
  }

  static getIPG() {
    return getAPI(path: '/v2/mikway/ipgreq');
  }

  static getSmartLink() {
    return getAPI(path: '/v2/mikway/link');
  }

  static setSmartLink(data) async {
    return await postAPI(path: '/v2/mikway/link', data: data);
  }

  static changeSmartLink(data) {
    return putAPI(path: '/v2/mikway/link', data: data);
  }

  static getSmartLinkSettings() {
    return getAPI(path: '/v2/mikway/link/setting');
  }

  static smartLinkSettings(data) async {
    return await postAPI(path: '/v2/mikway/link/setting', data: data);
  }

  static createPattern(data) async {
    return await postAPI(path: '/v2/mikway/sms/pattern', data: data);
  }

  static activePattern(code) {
    return getAPI(path: '/v2/mikway/sms/pattern/active/$code');
  }

  static deletePattern(code) {
    return deleteAPI(path: '/v2/mikway/sms/pattern/$code');
  }

  static patternStatus(code) {
    return getAPI(path: '/v2/mikway/sms/pattern/status/$code');
  }

  static sendSMS(data) async {
    return await postAPI(path: '/v2/mikway/sms/send', data: data);
  }

  static dataQuOK(data) async {
    return await postAPI(path: '/v2/status/dataQuOK', data: data);
  }

  static smsCredit() {
    return getAPI(path: '/v2/mikway/sms/credit');
  }

  static smsChargeHistory() {
    return getAPI(path: '/v2/mikway/sms/charge');
  }

  static smsCharge(data) async {
    return await postAPI(path: '/v2/mikway/sms/charge', data: data);
  }

  static dataQu() {
    return getAPI(path: '/dataQu');
  }

  static getMSGbyID(id) {
    return getAPI(path: '/rel/msg/id/$id');
  }

  static readMSG(id) {
    return putAPI(path: '/rel/msg/$id');
  }

  static pollMSG(id, poll) {
    return putAPI(path: '/rel/msg/poll/$id/$poll');
  }

  static getFile(fileName) async {
    final http = HTTP.io();
    try {
      var res = await http.get(Uri.https(url, '/rel/msg/file/$fileName'), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()});
      return (res.body);
    } catch (e) {
      return {'message': "خطا در دریافت اطلاعات!"};
    }
  }

  static ticket(data) async {
    return await postAPI(path: '/rel/ticket', data: data);
  }

  static updateTicket(data) {
    return putAPI(path: '/rel/ticket', data: data);
  }

  static closeTicket(id) {
    return putAPI(path: '/rel/ticket/close/$id');
  }

  static getTicket() {
    return getAPI(path: '/rel/ticket');
  }

  static getTicketbyID(id) {
    return getAPI(path: '/rel/ticket/$id');
  }

  //===MIKIF
  static getMikif() {
    //V1 is ok
    return getAPI(path: '/mikif');
  }

  static getMikifTR() {
    //V1 is ok
    return getAPI(path: '/mikif/tr');
  }

  static deposit(data) async {
    //V1 is ok
    return await postAPI(path: '/mikif/deposit', data: data);
  }

  static withdrawalReq(data) async {
    //V1 is ok
    return await postAPI(path: '/mikif/withdrawalreq', data: data);
  }

  static getWithdrawalReq() {
    //V1 is ok
    return getAPI(path: '/mikif/withdrawalreq');
  }

  static autoWithdrawal(data) async {
    //V1 is ok
    return await postAPI(path: '/mikif/autoWithdrawal', data: data);
  }

  static crmConnection() {
    return getAPI(path: '/v2/mikway/crm/connection');
  }

  static crmAddConnection(data) async {
    return await postAPI(path: '/v2/mikway/crm/connection', data: data);
  }

  static crmEditConnection(data) async {
    return await putAPI(path: '/v2/mikway/crm/connection', data: data);
  }

  static crmDeleteConnection(data) async {
    return await deleteAPI(path: '/v2/mikway/crm/connection', data: data);
  }

  static getClient() async {
    return await getAPI(path: '/v2/mikway/api');
  }

  static getClientbyClientName(name) async {
    return await getAPI(path: '/v2/mikway/api/$name');
  }

  static createClient(data) async {
    return await postAPI(path: '/v2/mikway/api', data: data);
  }

  static editClient(data) async {
    return await putAPI(path: '/v2/mikway/api', data: data);
  }

  static editActiveClient(data) async {
    return await putAPI(path: '/v2/mikway/api/active', data: data);
  }

  static deleteClient(data) async {
    return await deleteAPI(path: '/v2/mikway/api', data: data);
  }

  //==========================
  static getInCode(data) async {
    return postAPI(path: '/v2/mikway/connect/incode', data: data);
  }

  // ==============tax
  static getTSPSetting(tsp) {
    return getAPI(path: '/v2/mikway/tsp/setting', query: {'tsp': tsp});
  }

  static getTaxStatus(uid) {
    return getAPI(path: '/v2/mikway/tsp/invoice/status/$uid');
  }

  static toggleActiveTSPSetting(data) {
    return putAPI(path: '/v2/mikway/tsp/setting', data: data);
  }

  static postTSPSetting(data) {
    return postAPI(path: '/v2/mikway/tsp/setting', data: data);
  }

  static searchProductTaxID(query) {
    return getAPI(path: '/v2/mikway/tsp/search', query: query);
  }

  //============SEND PHOTOS FILE TO SERVER============
  static sendFile(data, {agin = false}) async {
    try {
      if (data['files'].isNotEmpty) {
        var request = httpClient.MultipartRequest("POST", Uri.https(url, '/v2/file'));
        //var request = http.MultipartRequest('POST', Uri.https(url, '/v2/file'));
        for (var i = 0; i < data['files'].length; i++) {
          request.files.add(await httpClient.MultipartFile.fromPath('photos', data['files'][i].toString()));
        }
        request.headers['auth-token'] = jwt.getAt(0)!.token.toString();
        request.fields.addAll(data['data']);
        var res = await DebugHttpClient.sendRequest(request);
        // var res = await http.send(request);
        var responseData = await res.stream.toBytes();
        var result = String.fromCharCodes(responseData);
        print("res send File: $responseData");
        if (result.toString() != '200') {
          if (!agin) {
            await dataToServer.add(DataToServer(data: data, type: 'pic'));
            dataQueueFlag.value = dataQueue.isNotEmpty || dataToServer.isNotEmpty;
          }
        }
        return result.toString();
      } else {
        return '';
      }
    } catch (e) {
      print("ERR: $e");
      if (e.toString() == "type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, String>'") {
        return '200';
      }
      if (!agin) {
        await dataToServer.add(DataToServer(data: data, type: 'pic'));
        dataQueueFlag.value = dataQueue.isNotEmpty || dataToServer.isNotEmpty;
      }
    }
  }

  //DELETE FILES
  static delFile(item) {
    return deleteAPI(path: '/v2/file', data: item);
  }

  //======= DATA QUEUE =======//

  static bool isrun = false;
  static sendDataQueue() async {
    final http = HTTP.io();
    if (serverAvailable) {
      isrun = true;
      dataQueue = await Hive.openBox<DataQueue>('dataQueue');
      //print("Data QUEUE: ${dataQueue.length}");
      for (int i = 0; i < dataQueue.length; i++) {
        print("Data QUEUE: ${dataQueue.getAt(i)!.toJson()}");
        if (dataQueue.values.toList()[i].url == '/v2/file') {
          var res = await sendFile(dataQueue.values.toList()[i].data, agin: true);
          print(res);
          print('=================');
          if (res == '200') await dataQueue.deleteAt(i);
        } else {
          print('noFile');
          var res = await http.post(
            Uri.https(url, dataQueue.getAt(i)!.url.toString()),
            headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()},
            body: dataQueue.getAt(i)!.data ?? '',
          );

          if (res.statusCode == 200) await dataQueue.deleteAt(i);
        }
        Future.delayed(const Duration(milliseconds: 100));
        dataQueueFlag.value = dataQueue.isNotEmpty || dataToServer.isNotEmpty;
      }
      isrun = false;
      return '200';
    } else {
      print('not connect to Internet');
      return 'not connect';
    }
  }

  //======= API Func =======//
  static postAPI({path, data}) async {
    final http = HTTP.io();
    if (!serverAvailable) await server();
    if (serverAvailable) {
      try {
        data['app'] = 'mik';
        var res = await http
            .post(Uri.https(url, path), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()}, body: jsonEncode(data))
            .timeout(const Duration(seconds: 5));

        return res;
        // if (res.statusCode == 200 && res.body != '400') {
        //   return res.body;
        // } else {
        //   print('400');
        //   if (path != '/accpkg/charge' &&
        //       path != '/sms/send' &&
        //       path != '/sms/pattern' &&
        //       path != '/sl/link' &&
        //       path != '/mikif/deposit') saveDataQueue(data, path);
        //   return '400';
        // }
      } catch (e) {
        // if (path != '/accpkg/charge' &&
        //     path != '/sms/send' &&
        //     path != '/sms/pattern' &&
        //     path != '/sl/link' &&
        //     path != '/mikif/deposit') saveDataQueue(data, path);
        // print("ERR: $e");
        return const Response(statusCode: 400, body: '400');
      }
    } else {
      return const Response(statusCode: 400, body: '400');
      // if (path != '/accpkg/charge' &&
      //     path != '/sms/send' &&
      //     path != '/sms/pattern' &&
      //     path != '/sl/link' &&
      //     path != '/mikif/deposit') saveDataQueue(data, path);
    }
  }

  static getAPI({path, query}) async {
    final http = HTTP.io();
    if (!serverAvailable) await server();
    try {
      var res = await http.get(Uri.https(url, path, query), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()}).timeout(const Duration(milliseconds: 6000));
      if (path.toString().startsWith('/sms/pattern/deactive/')) {
        return res.body;
      } else {
        //return jsonDecode(res.body);
        var body;
        try {
          body = jsonDecode(res.body);
        } catch (e) {
          body = res.body;
        }

        return {"message": "success", "hasError": false, "data": body};
      }
    } catch (e) {
      print(e);
      return {"message": "خطا در دریافت اطلاعات!", "hasError": true};
    }
  }

  static putAPI({path, data}) async {
    final http = HTTP.io();
    if (!serverAvailable) await server();
    if (serverAvailable) {
      try {
        data['app'] = 'mik';
        var res = await http
            .put(Uri.https(url, path), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()}, body: data != null ? jsonEncode(data) : null)
            .timeout(const Duration(milliseconds: 5000));
        // if (res.statusCode == 200 && res.body != '400') {
        return res;
        // } else {
        //   return Response(statusCode: 400, body: '400');
        //   // return '400';
        // }
      } catch (e) {
        return const Response(statusCode: 400, body: '400');
        // return '400';
      }
    } else {
      return const Response(statusCode: 400, body: '400');
      // return 'server Error';
    }
  }

  static deleteAPI({path, data}) async {
    final http = HTTP.io();
    if (!serverAvailable) await server();
    if (serverAvailable) {
      try {
        var res = await http
            .delete(Uri.https(url, path), headers: {"Content-Type": "application/json", 'auth-token': jwt.getAt(0)!.token.toString()}, body: jsonEncode(data))
            .timeout(const Duration(milliseconds: 5000));
        if (res.statusCode == 200 && res.body != '400') {
          return res.body;
        } else {
          return '400';
        }
      } catch (e) {
        return '400';
      }
    } else {
      return 'server Error';
    }
  }

  //===================
}
