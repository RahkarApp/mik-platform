import 'dart:convert';

import 'package:get/get.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/models.dart';
import '../../source/remote/pim_store.dart';
import 'business_context.dart';

class PimFX {
  static final _contexts = Expando<PimFX>();
  static PimFX forContext(BusinessContext context) =>
      _contexts[context] ??= PimFX(context: context);
  final BusinessContext context;
  final PimCommandStore store;
  final accessVersion = 0.obs;
  ScopeAuthorization? _authorization;
  PimCommand? pending;
  Future<PimResult>? _sending;
  String? _sendingIntent;
  PimFX({required this.context, this.store = const SecurePimStore()});
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/pim';
  String get _storeKey =>
      'pim.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId';
  bool has(String code) {
    accessVersion.value;
    return context.valid &&
        _authorization?.permissionCodes.contains(code) == true;
  }

  void require(String code) {
    context.check();
    if (!has(code)) throw const AuthError(403, 'FORBIDDEN');
  }

  bool canChange(PimResource resource, PimRecord item, {bool archive = false}) {
    if (item.businessId != businessId) return false;
    final code = archive
        ? resource.archivePermission
        : '${resource.permission}.update';
    final ownOnly = [
      PimResource.attributes,
      PimResource.prices,
      PimResource.overrides,
    ].contains(resource);
    return has(code) &&
        (!ownOnly ||
            item.createdBy.identityId == context.session.identityId ||
            has('$code.all'));
  }

  Future<void> authorize() async {
    // A child page can share this FX with its parent; notify after its build.
    await Future<void>.value();
    context.check();
    _authorization = null;
    accessVersion.value++;
    final result = ScopeAuthorization.fromJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/$businessId/authorization',
        query: {'scopeType': 'BUSINESS', 'scopeId': '$businessId'},
      ),
    );
    context.check();
    if (!result.allowed ||
        result.businessId != businessId ||
        result.membershipId != context.session.business.membershipId ||
        result.scopeType != 'BUSINESS' ||
        result.scopeId != '$businessId') {
      throw const FormatException('Unexpected business authorization');
    }
    _authorization = result;
    accessVersion.value++;
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? key,
  }) async {
    context.check();
    try {
      final result = await context.request(
        method,
        path,
        query: query,
        data: body,
        idempotencyKey: key,
      );
      context.check();
      return result;
    } on AuthError catch (error) {
      if (error.statusCode == 403 || error.requiresLogin) {
        _authorization = null;
        accessVersion.value++;
      }
      rethrow;
    }
  }

  Future<PimPage> page(
    PimResource resource, {
    String? after,
    Map<String, String> filters = const {},
  }) async {
    require('${resource.permission}.read');
    final result = PimPage.fromJson(
      await _request(
        'GET',
        '$_base/${resource.path}',
        query: {'limit': '100', 'after': ?after, ...filters},
      ),
      resource,
    );
    if (result.businessId != businessId) {
      throw const FormatException('Unexpected PIM business');
    }
    return result;
  }

  Future<List<PimRecord>> all(
    PimResource resource, {
    Map<String, String> filters = const {},
  }) async {
    final result = <PimRecord>[];
    final cursors = <String>{};
    String? cursor;
    do {
      final next = await page(resource, after: cursor, filters: filters);
      result.addAll(next.items);
      cursor = next.nextCursor;
      if (cursor != null && !cursors.add(cursor)) {
        throw const FormatException('Repeated PIM cursor');
      }
    } while (cursor != null);
    return List.unmodifiable(result);
  }

  Future<PimRecord> get(PimResource resource, String id) async {
    require('${resource.permission}.read');
    final json = RemoteJson(
      await _request(
        'GET',
        '$_base/${resource.path}/${Uri.encodeComponent(id)}',
      ),
    );
    final result = resource.parse(json.value['item']);
    if (json.number('businessId') != businessId ||
        result.businessId != businessId ||
        result.id != id) {
      throw const FormatException('Unexpected PIM record');
    }
    return result;
  }

  Future<ProductCatalog> catalog({String? parentCode, String? after}) async =>
      ProductCatalog.fromJson(
        await _request(
          'GET',
          '/v1/catalog/products',
          query: {'limit': '100', 'parentCode': ?parentCode, 'after': ?after},
        ),
      );
  Future<PimPreview> preview(String productId, {List<PimAxis>? axes}) async {
    require('pim.variant.create');
    require('pim.product.read');
    final result = PimPreview.fromJson(
      await _request(
        'POST',
        '$_base/variants/preview',
        body: {
          'productId': productId,
          if (axes != null) 'axes': axes.map((axis) => axis.toJson()).toList(),
        },
      ),
    );
    if (result.productId != productId) {
      throw const FormatException('Unexpected preview product');
    }
    return result;
  }

  Future<PimEffectivePrice> effectivePrice(
    String variantId, {
    String? priceId,
  }) async {
    require('pim.price.read');
    final result = PimEffectivePrice.fromJson(
      await _request(
        'GET',
        '$_base/variants/${Uri.encodeComponent(variantId)}/price',
        query: {'productPriceId': ?priceId},
      ),
    );
    if (result.businessId != businessId ||
        result.variantId != variantId ||
        priceId != null && result.productPriceId != priceId ||
        result.currency != 'TOMAN') {
      throw const FormatException('Unexpected effective price');
    }
    return result;
  }

  Future<PimCommand?> restore() async {
    context.check();
    final result = await store.read(_storeKey);
    context.check();
    return pending = result;
  }

  PimCommand change(
    PimResource resource,
    Map<String, dynamic> fields, {
    PimRecord? item,
  }) {
    if (pending != null) throw const AuthError(409, 'PIM_PENDING');
    if (item != null && item.businessId != businessId) {
      throw const FormatException('Unexpected PIM business');
    }
    return PimCommand(
      resource: resource,
      operation: item == null ? 'create' : 'update',
      id: item?.id,
      creatorIdentityId: item?.createdBy.identityId,
      body: {...fields, if (item != null) 'expectedRevision': item.revision},
    );
  }

  PimCommand operation(String path, Map<String, dynamic> body) {
    if (pending != null) throw const AuthError(409, 'PIM_PENDING');
    if (![
      'initialize',
      'categories/import',
      'variants/generate',
    ].contains(path)) {
      throw ArgumentError.value(path);
    }
    return PimCommand(operation: path, body: body);
  }

  void checkCommand(PimCommand command) {
    final resource = command.resource;
    if (command.operation == 'convert-to-variable') {
      if (resource != PimResource.products || command.id == null) {
        throw const FormatException('Invalid conversion target');
      }
      for (final permission in [
        'pim.product.update',
        'pim.attribute.assign',
        'pim.variant.update',
      ]) {
        require(permission);
      }
      return;
    }
    if (resource == null) {
      if (![
            'initialize',
            'categories/import',
            'variants/generate',
          ].contains(command.operation) ||
          command.id != null) {
        throw const FormatException('Invalid PIM operation');
      }
      require(
        command.operation == 'variants/generate'
            ? 'pim.variant.create'
            : 'pim.product.category.import',
      );
      if (command.operation == 'variants/generate') require('pim.variant.read');
      return;
    }
    if (!['create', 'update'].contains(command.operation) ||
        (command.operation == 'update') != (command.id != null)) {
      throw const FormatException('Invalid PIM command');
    }
    final body = command.body;
    final archive = command.id != null && body['status'] == 'ARCHIVED';
    final code = archive
        ? resource.archivePermission
        : '${resource.permission}.${command.id == null ? 'create' : 'update'}';
    require(code);
    if (command.id != null &&
        [
          PimResource.attributes,
          PimResource.prices,
          PimResource.overrides,
        ].contains(resource) &&
        command.creatorIdentityId != context.session.identityId) {
      require('$code.all');
    }
    if (resource == PimResource.products) {
      if (body.keys.any(['attributeValues', 'variantAxes'].contains)) {
        require('pim.attribute.assign');
      }
      if (body.keys.any(
        [
          'shortDescription',
          'description',
          'media',
          'webContent',
          'relatedProductIds',
        ].contains,
      )) {
        require('pim.product.shop.update');
      }
    }
    if (resource == PimResource.prices && body.containsKey('isDefault')) {
      require('pim.price.default.update');
    }
  }

  Future<PimResult> execute(PimCommand command) {
    if (_sending != null) {
      if (_sendingIntent != jsonEncode(command.toJson())) {
        return Future.error(const AuthError(409, 'PIM_PENDING'));
      }
      return _sending!;
    }
    _sendingIntent = jsonEncode(command.toJson());
    return _sending = _execute(command).whenComplete(() {
      _sending = null;
      _sendingIntent = null;
    });
  }

  Future<PimResult> _execute(PimCommand command) async {
    checkCommand(command);
    final saved = await restore();
    if (saved != null &&
        jsonEncode(saved.toJson()) != jsonEncode(command.toJson())) {
      throw const AuthError(409, 'PIM_PENDING');
    }
    pending = command;
    await store.write(_storeKey, command);
    context.check();
    try {
      final resource = command.resource;
      final converting = command.operation == 'convert-to-variable';
      final path = converting
          ? 'products/${Uri.encodeComponent(command.id!)}/convert-to-variable'
          : resource == null
          ? command.operation
          : '${resource.path}${command.id == null ? '' : '/${Uri.encodeComponent(command.id!)}'}';
      final response = await _request(
        converting || command.id == null ? 'POST' : 'PATCH',
        '$_base/$path',
        body: command.body,
        key: command.idempotencyKey,
      );
      final raw = RemoteJson(response);
      final result = PimResult.fromJson(
        converting
            ? {
                ...raw.value,
                'item': raw.value['product'],
                'baseVariant': raw.value['variant'],
              }
            : response,
        resource: resource,
      );
      if (converting) {
        final variant = result.baseVariant;
        final body = command.body;
        if (result.item?.revision != body['expectedRevision'] + 1 ||
            variant == null ||
            variant.id != body['variantId'] ||
            variant.revision != body['expectedVariantRevision'] + 1 ||
            variant.optionValues.length !=
                (body['optionValues'] as List).length ||
            variant.optionValues.any(
              (pair) => !(body['optionValues'] as List).any(
                (expected) =>
                    expected['attributeId'] == pair.attributeId &&
                    expected['valueId'] == pair.valueId,
              ),
            )) {
          throw const FormatException('Unexpected conversion confirmation');
        }
      }
      if (result.businessId != businessId ||
          result.baseVariant != null &&
              result.baseVariant!.productId != result.item?.id ||
          result.item is PimVariant &&
              command.body['productId'] != null &&
              (result.item as PimVariant).productId !=
                  command.body['productId'] ||
          result.item is PimPrice &&
              command.body['productId'] != null &&
              (result.item as PimPrice).productId !=
                  command.body['productId'] ||
          command.id != null && result.item?.id != command.id ||
          command.operation == 'variants/generate' &&
              (result.createdCount == null ||
                  result.variants.any(
                    (v) => v.productId != command.body['productId'],
                  )) ||
          ['initialize', 'categories/import'].contains(command.operation) &&
              (result.importedCount == null || result.catalogVersion == null)) {
        throw const FormatException('Unexpected PIM result');
      }
      await store.clear(_storeKey);
      pending = null;
      return result;
    } on AuthError catch (error) {
      if (error.statusCode < 500 &&
          !error.retryable &&
          !error.requiresLogin &&
          error.statusCode != 403) {
        await store.clear(_storeKey);
        pending = null;
      }
      rethrow;
    }
  }

  static String message(Object error) {
    if (error is AuthError) {
      switch (error.code) {
        case 'FORBIDDEN':
          return 'اجازه انجام این عملیات را ندارید. دسترسی‌ها را دوباره دریافت کنید.';
        case 'REVISION_CONFLICT':
          return 'اطلاعات تغییر کرده است. نسخه جدید را دریافت کنید.';
        case 'PIM_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی هنوز تعیین تکلیف نشده؛ همان درخواست را دوباره ارسال کنید.';
        case 'PRICE_UNAVAILABLE':
          return 'قیمت نیازمند اصلاح است.';
        case 'DUPLICATE_RECORD':
          return 'کد، بارکد یا مشخصات این رکورد تکراری است.';
        case 'VALIDATION_FAILED':
          return 'اطلاعات و ارتباط‌های محصول را بررسی کنید.';
        case 'RECORD_NOT_FOUND':
          return 'این مورد در کسب‌وکار انتخاب‌شده وجود ندارد.';
      }
    }
    if (error is FormatException) {
      return 'پاسخ سرور کامل نیست. دوباره تلاش کنید.';
    }
    return API.loginError(error);
  }
}
