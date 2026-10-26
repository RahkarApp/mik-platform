import 'package:mik_data/utils/fx/realtime.dart';
import 'package:get/get.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/product_facts.dart';

class ProductDetailController extends GetxController {
  final String appId, productId;
  final int businessId;
  final loading = false.obs, saving = false.obs, statusConflict = false.obs;
  final statusError = RxnString(), statusNotice = RxnString();
  final pendingStatus = Rxn<PimCommand>();
  final error = RxnString(), variantsError = RxnString();
  final product = Rxn<PimProduct>();
  final variants = <PimVariant>[].obs;
  final names = <String, String>{}.obs;
  BusinessContext? _context;
  ProductFactsFX? facts;
  RealtimeWatch? _realtime;
  bool _closed = false;
  int _generation = 0;
  ProductDetailController({
    required this.appId,
    required this.businessId,
    required this.productId,
  });

  void _check(BusinessContext context) {
    context.check();
    if (!identical(context, _context) ||
        context.session.business.businessId != businessId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> refreshFromServer() async {
    while (!_closed && (loading.value || saving.value)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!_closed) await load(background: true);
  }

  Future<void> load({bool background = false}) async {
    if (saving.value) return;
    final generation = ++_generation;
    if (!background) loading.value = true;
    error.value = null;
    variantsError.value = null;
    if (!background) {
      product.value = null;
      variants.clear();
      names.clear();
      facts = null;
    }
    try {
      final context = BusinessContext.forApp(appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      // Keep this page bound to its original session, even when retried after an account switch.
      _context ??= context;
      _realtime ??= RealtimeWatch(
        RealtimeFX.forContext(context),
        {
          'pim.product',
          'pim.variant',
          'pim.price',
          'pim.price-override',
          'pim.category',
          'pim.brand',
          'pim.attribute',
          'inventory.balance',
        },
        refreshFromServer,
        invalidate: () {
          if (!saving.value) _generation++;
          loading.value = false;
          product.value = null;
          variants.clear();
          names.clear();
          facts = null;
        },
      );
      _check(context);
      final fx = PimFX.forContext(context);
      await fx.authorize();
      final item = await fx.get(PimResource.products, productId) as PimProduct;
      _check(context);
      if (generation != _generation) return;
      if (!['ACTIVE', 'DRAFT', 'ARCHIVED'].contains(item.status)) {
        throw const FormatException('Unexpected product status');
      }
      final rows = <PimVariant>[];
      if (fx.has('pim.variant.read')) {
        try {
          rows.addAll(
            (await fx.all(
              PimResource.variants,
              filters: {'productId': productId},
            )).cast<PimVariant>(),
          );
          if (rows.any(
                (v) =>
                    v.productId != productId ||
                    !['ACTIVE', 'ARCHIVED'].contains(v.status),
              ) ||
              rows.map((v) => v.id).toSet().length != rows.length) {
            throw const FormatException('Unexpected product variants');
          }
        } catch (failure) {
          if (failure is AuthError &&
              (failure.statusCode == 403 || failure.requiresLogin)) {
            rethrow;
          }
          if (generation != _generation) return;
          rows.clear();
          variantsError.value = PimFX.message(failure);
        }
      } else {
        variantsError.value = 'اجازه مشاهده تنوع‌های این محصول را ندارید.';
      }
      final labels = <String, String>{};
      // Names are separate authorized records; absent grants leave explicit IDs, not guessed labels.
      for (final resource in [
        PimResource.categories,
        PimResource.brands,
        PimResource.attributes,
      ]) {
        if (!fx.has('${resource.permission}.read')) continue;
        final ids = switch (resource) {
          PimResource.categories => item.categoryIds.toSet(),
          PimResource.brands => {if (item.brandId != null) item.brandId!},
          _ => {
            ...item.attributeValues.map((v) => v.attributeId),
            for (final v in rows) ...v.optionValues.map((o) => o.attributeId),
          },
        };
        for (final id in ids) {
          final record = await fx.get(resource, id);
          labels[id] = record.name;
          if (record is PimAttribute) {
            for (final value in record.values) {
              labels['$id/${value.valueId}'] = value.name;
            }
          }
        }
      }
      _check(context);
      if (generation != _generation) return;
      final command =
          fx.has('pim.product.update') || fx.has('pim.product.archive')
          ? await fx.restore()
          : null;
      _check(context);
      if (generation != _generation) return;
      pendingStatus.value = command;
      statusError.value = null;
      statusConflict.value = false;
      names.assignAll(labels);
      variants.assignAll(rows);
      facts = ProductFactsFX(fx);
      product.value = item;
    } catch (failure) {
      if (generation == _generation) {
        product.value = null;
        variants.clear();
        names.clear();
        facts = null;
        error.value = ProductFactsFX.message(failure);
      }
    } finally {
      if (generation == _generation) loading.value = false;
    }
  }

  bool get pendingHere {
    final p = pendingStatus.value;
    return p?.resource == PimResource.products &&
        p?.id == productId &&
        p?.operation == 'update' &&
        ['DRAFT', 'ACTIVE', 'ARCHIVED'].contains(p!.body['status']) &&
        p.body.keys.every({'status', 'expectedRevision'}.contains);
  }

  bool canStatus(String target) {
    final item = product.value, fx = facts?.pim;
    if (loading.value ||
        saving.value ||
        statusConflict.value ||
        pendingStatus.value != null ||
        item == null ||
        fx == null) {
      return false;
    }
    final valid = switch (item.status) {
      'DRAFT' => ['ACTIVE', 'ARCHIVED'].contains(target),
      'ACTIVE' => ['DRAFT', 'ARCHIVED'].contains(target),
      'ARCHIVED' => target == 'DRAFT',
      _ => false,
    };
    return valid &&
        fx.canChange(PimResource.products, item, archive: target == 'ARCHIVED');
  }

  Future<void> changeStatus(String target) async {
    final fx = facts?.pim, item = product.value, context = _context;
    if (loading.value ||
        saving.value ||
        statusConflict.value ||
        fx == null ||
        item == null ||
        context == null) {
      return;
    }
    if (pendingStatus.value != null) {
      if (!pendingHere || pendingStatus.value!.body['status'] != target) return;
    } else if (!canStatus(target)) {
      return;
    }
    final generation = _generation;
    saving.value = true;
    statusError.value = null;
    statusNotice.value = null;
    var success = false;
    try {
      _check(context);
      // Preserve status, revision and key on retries; the first request may already have committed.
      pendingStatus.value ??= fx.change(PimResource.products, {
        'status': target,
      }, item: item);
      final result = await fx.execute(pendingStatus.value!);
      _check(context);
      if (generation != _generation) return;
      if (result.item is! PimProduct ||
          result.item!.id != productId ||
          result.item!.status != target) {
        throw const FormatException('Unexpected product status result');
      }
      product.value = result.item as PimProduct;
      pendingStatus.value = null;
      statusNotice.value = 'وضعیت محصول ذخیره شد.';
      success = true;
    } catch (failure) {
      if (generation != _generation) return;
      statusConflict.value =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      pendingStatus.value = fx.pending;
      statusError.value =
          failure is AuthError &&
              failure.code == 'VALIDATION_FAILED' &&
              target == 'ACTIVE'
          ? 'فعال‌سازی تأیید نشد؛ تنوع فعال، قیمت پیش‌فرض معتبر و مشخصات محصول را بررسی کنید.'
          : PimFX.message(failure);
    } finally {
      saving.value = false;
    }
    if (success && generation == _generation) await load();
  }

  String label(String id) => names[id] ?? id;
  String option(String attributeId, String valueId) =>
      names['$attributeId/$valueId'] ?? valueId;
  @override
  void onClose() {
    _closed = true;
    _realtime?.dispose();
    _generation++;
    super.onClose();
  }
}
