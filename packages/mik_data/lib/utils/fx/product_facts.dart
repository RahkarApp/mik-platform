import '../../source/remote/auth_error.dart';
import '../../source/remote/models/inventory_availability.dart';
import '../../source/remote/models/inventory_quantity.dart';
import '../../source/remote/models/models.dart';
import 'pim.dart';

class ProductPriceSummary {
  final int? minimum, maximum;
  final String? message;
  final Map<String, ProductPriceSummary> variants;
  const ProductPriceSummary({
    this.minimum,
    this.maximum,
    this.message,
    this.variants = const {},
  });
}

class ProductStockSummary {
  final InventoryQuantity? available;
  final bool blockedForCount;
  final Map<String, VariantAvailability> variants;
  final String? message;
  const ProductStockSummary({
    this.available,
    this.blockedForCount = false,
    this.message,
    this.variants = const {},
  });
}

class ProductFacts {
  final ProductPriceSummary price;
  final ProductStockSummary stock;
  const ProductFacts(this.price, this.stock);
}

/// Read-only facts for a row: all valid price titles and default-warehouse availability.
class ProductFactsFX {
  final PimFX pim;
  ProductFactsFX(this.pim);

  void _check(String? branchId) {
    pim.context.check();
    if (pim.context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<ProductFacts> load(PimProduct product) async {
    pim.context.check();
    final branchId = pim.context.selectedBranch?.branchId;
    if (product.businessId != pim.businessId) {
      throw const FormatException('Unexpected product business');
    }
    if (product.status != 'ACTIVE') {
      return const ProductFacts(
        ProductPriceSummary(
          message: 'قیمت فقط برای محصول فعال قابل دریافت است.',
        ),
        ProductStockSummary(
          message: 'موجودی قابل فروش فقط برای محصول فعال قابل دریافت است.',
        ),
      );
    }
    if (!pim.has('pim.variant.read')) {
      return const ProductFacts(
        ProductPriceSummary(
          message: 'اجازه مشاهده تنوع‌های این محصول را ندارید.',
        ),
        ProductStockSummary(
          message: 'اجازه مشاهده تنوع‌های این محصول را ندارید.',
        ),
      );
    }
    final variants = (await pim.all(
      PimResource.variants,
      filters: {'productId': product.id, 'status': 'ACTIVE'},
    )).cast<PimVariant>();
    _check(branchId);
    if (variants.any(
          (v) => v.productId != product.id || v.status != 'ACTIVE',
        ) ||
        variants.map((v) => v.id).toSet().length != variants.length) {
      throw const FormatException('Unexpected product variants');
    }
    if (variants.isEmpty) {
      return const ProductFacts(
        ProductPriceSummary(message: 'تنوع فعالی برای این محصول وجود ندارد.'),
        ProductStockSummary(message: 'تنوع فعالی برای این محصول وجود ندارد.'),
      );
    }
    // Failures are shown per cell; an unavailable price must not turn stock into zero.
    final price = _price(product, variants, branchId);
    final stock = _stock(product, variants, branchId);
    final result = ProductFacts(await price, await stock);
    _check(branchId);
    return result;
  }

  Future<ProductPriceSummary> _price(
    PimProduct product,
    List<PimVariant> variants,
    String? branchId,
  ) async {
    if (!pim.has('pim.price.read')) {
      return const ProductPriceSummary(message: 'اجازه مشاهده قیمت را ندارید.');
    }
    try {
      final titles = (await pim.all(
        PimResource.prices,
        filters: {'productId': product.id, 'status': 'ACTIVE'},
      )).cast<PimPrice>();
      _check(branchId);
      if (titles.any(
            (p) =>
                p.productId != product.id ||
                p.status != 'ACTIVE' ||
                p.currency != 'TOMAN',
          ) ||
          titles.map((p) => p.id).toSet().length != titles.length) {
        throw const FormatException('Unexpected price titles');
      }
      int? minimum, maximum;
      final byVariant = <String, ProductPriceSummary>{};
      for (final title in titles) {
        final amounts = <int>[];
        for (final variant in variants) {
          try {
            final resolved = await pim.effectivePrice(
              variant.id,
              priceId: title.id,
            );
            _check(branchId);
            if (resolved.productId != product.id) {
              throw const FormatException('Unexpected price product');
            }
            amounts.add(resolved.amount);
          } on AuthError catch (error) {
            // The server decides title validity using its own clock. No substitute title is guessed.
            if (error.code != 'PRICE_UNAVAILABLE') rethrow;
            amounts.clear();
            break;
          }
        }
        // Keep each validated title complete before adding its variant prices.
        for (var i = 0; i < amounts.length; i++) {
          final id = variants[i].id, amount = amounts[i];
          final previous = byVariant[id];
          byVariant[id] = ProductPriceSummary(
            minimum: previous?.minimum == null || amount < previous!.minimum!
                ? amount
                : previous.minimum,
            maximum: previous?.maximum == null || amount > previous!.maximum!
                ? amount
                : previous.maximum,
          );
        }
        for (final amount in amounts) {
          minimum = minimum == null || amount < minimum ? amount : minimum;
          maximum = maximum == null || amount > maximum ? amount : maximum;
        }
      }
      return ProductPriceSummary(
        minimum: minimum,
        maximum: maximum,
        variants: Map.unmodifiable(byVariant),
        message: minimum == null ? 'عنوان قیمت معتبر فعالی وجود ندارد.' : null,
      );
    } catch (error) {
      return ProductPriceSummary(message: message(error));
    }
  }

  Future<ProductStockSummary> _stock(
    PimProduct product,
    List<PimVariant> variants,
    String? branchId,
  ) async {
    if (branchId == null) {
      return const ProductStockSummary(message: 'ابتدا شعبه را انتخاب کنید.');
    }
    if (!pim.context.hasPermission('inventory.stock.read', inBranch: true)) {
      return const ProductStockSummary(
        message: 'اجازه مشاهده موجودی این شعبه را ندارید.',
      );
    }
    try {
      InventoryQuantity? total;
      final byVariant = <String, VariantAvailability>{};
      String? warehouseId;
      var blocked = false;
      // Availability accepts at most 30 variant IDs. Omitting warehouseIds uses the server's default.
      for (var start = 0; start < variants.length; start += 30) {
        final batch = variants.skip(start).take(30).toList();
        final result = InventoryAvailability.fromJson(
          await pim.context.request(
            'POST',
            '/v1/businesses/${pim.businessId}/inventory/availability',
            data: {'variantIds': batch.map((v) => v.id).toList()},
          ),
        );
        _check(branchId);
        if (result.businessId != product.businessId ||
            result.items.length != batch.length ||
            result.items.map((v) => v.variantId).toSet().length !=
                batch.length) {
          throw const FormatException('Unexpected inventory scope');
        }
        final ids = batch.map((v) => v.id).toSet();
        for (final item in result.items) {
          if (!ids.contains(item.variantId) ||
              item.productId != product.id ||
              item.unitId != product.unitId ||
              !item.active ||
              item.warehouses.length != 1) {
            throw const FormatException('Unexpected inventory variant');
          }
          final warehouse = item.warehouses.single;
          warehouseId ??= warehouse.warehouseId;
          if (warehouse.warehouseId != warehouseId ||
              item.available.toString() != warehouse.available.toString() ||
              warehouse.blockedForCount && !item.available.isZero) {
            throw const FormatException('Unexpected default warehouse stock');
          }
          blocked = blocked || warehouse.blockedForCount;
          total = total == null ? item.available : total + item.available;
          byVariant[item.variantId] = item;
        }
      }
      return ProductStockSummary(
        available: total,
        blockedForCount: blocked,
        variants: Map.unmodifiable(byVariant),
      );
    } catch (error) {
      return ProductStockSummary(message: message(error));
    }
  }

  static String message(Object error) {
    if (error is AuthError) {
      if (error.code == 'DEFAULT_WAREHOUSE_UNAVAILABLE') {
        return 'انبار پیش‌فرض شعبه تنظیم نشده یا در دسترس نیست.';
      }
      if (error.code == 'SELECTION_CHANGED') {
        return 'شعبه یا کسب‌وکار تغییر کرده است؛ دوباره تلاش کنید.';
      }
    }
    return PimFX.message(error);
  }
}
