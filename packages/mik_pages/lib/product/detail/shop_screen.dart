import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/shop.dart';
import 'package:mik_data/utils/fx/pim.dart';

import 'shop_publication.dart';

class ProductShopScreen extends StatefulWidget {
  final BusinessContext business;
  final String productId, productName;
  const ProductShopScreen({
    super.key,
    required this.business,
    required this.productId,
    required this.productName,
  });
  @override
  State<ProductShopScreen> createState() => _ProductShopScreenState();
}

class _ProductShopScreenController extends GetxController {
  _ProductShopScreenController(this.widget);
  ProductShopScreen widget;
  late final fx = ShopFX(widget.business);
  final publications =
      <String, ({bool excluded, String? priceId, int revision})>{};
  List<RemoteShop> shops = [];
  String? error;
  bool loading = false;
}

class _ProductShopScreenState extends State<ProductShopScreen> {
  late final _page = _ProductShopScreenController(widget);

  Future<Object> load({bool initial = false}) async {
    if (_page.loading) return '';
    void begin() {
      _page.loading = true;
      _page.error = null;
      _page.shops = [];
      _page.publications.clear();
    }

    if (initial) {
      begin();
    } else {
      {
        begin();
        _page.update();
      }
    }
    try {
      await _page.fx.authorize();
      await _page.fx.restoreManagement();
      if (!_page.fx.has('shop.publication.read')) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      final stores = await _page.fx.list();
      final rows = <String, ({bool excluded, String? priceId, int revision})>{};
      for (final store in stores) {
        rows[store.id] = await _page.fx.publication(store.id, widget.productId);
      }
      _page.fx.check();
      if (mounted) {
        {
          _page.shops = stores;
          _page.publications.addAll(rows);
          _page.update();
        }
      }
    } catch (failure) {
      if (mounted) {
        {
          _page.error = PimFX.message(failure);
          _page.update();
        }
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ProductShopScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () => load(initial: true),
      header: Header.page(context, text: 'شاپ ${widget.productName}'),
      child: (_) => Column(
        children: [
          if (_page.loading) const LinearProgressIndicator(),
          if (_page.error != null)
            Text(_page.error!, textAlign: TextAlign.center),
          Expanded(
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10),
                children: [
                  if (!_page.loading &&
                      _page.error == null &&
                      _page.shops.isEmpty)
                    EmptyList(
                      text: 'فروشگاهی برای این کسب‌وکار ثبت نشده است.',
                      icon: IconsaxPlusLinear.shop,
                    ),
                  for (final shop in _page.shops) ...[
                    MyDivider(text: shop.name),
                    Text(
                      'انتشار کالا: ${_page.publications[shop.id]!.excluded ? 'مستثنا شده' : 'مستثنا نشده'}',
                    ),
                    Text('فروشگاه: ${shop.enabled ? 'فعال' : 'غیرفعال'}'),
                    Text(
                      'راه‌اندازی: ${switch (shop.status) {
                        'ACTIVE' => 'فعال',
                        'PROVISIONING' => 'در حال آماده‌سازی',
                        _ => 'معلق',
                      }}',
                    ),
                    Text(
                      'همگام‌سازی: ${switch (shop.syncStatus) {
                        'READY' => 'آماده',
                        'FAILED' => 'ناموفق',
                        'PROCESSING' => 'در حال پردازش',
                        _ => 'در انتظار',
                      }}',
                    ),
                    Text(
                      _page.publications[shop.id]!.priceId == null
                          ? 'قیمت: عنوان پیش‌فرض محصول'
                          : 'عنوان قیمت اختصاصی: ${_page.publications[shop.id]!.priceId}',
                    ),
                    if (_page.fx.has('shop.publication.update'))
                      BTN(
                        navigate: true,
                        name: 'ویرایش انتشار کالا',
                        borderOnly: true,
                        disabled:
                            _page.loading || _page.fx.managementPending != null,
                        onTap: () async {
                          final changed = await editShopPublication(
                            context,
                            _page.fx,
                            shop,
                            widget.productId,
                            widget.productName,
                          );
                          if (changed && mounted) await load();
                        },
                      ),
                    const SizedBox(height: 10),
                  ],
                  if (_page.shops.isNotEmpty)
                    const Text(
                      'مستثنا نبودن به‌تنهایی به معنای قابل خرید بودن نیست؛ وضعیت محصول، قیمت، موجودی و آماده بودن فروشگاه نیز بررسی می‌شوند.',
                    ),
                ],
              ),
            ),
          ),
          if (_page.fx.managementPending != null)
            BTN(
              name: 'پیگیری عملیات فروشگاه',
              disabled: _page.loading,
              onTap: () async {
                try {
                  await _page.fx.manage(_page.fx.managementPending!);
                  if (mounted) {
                    Alert.success('عملیات فروشگاه تأیید شد.');
                    await load();
                  }
                } catch (failure) {
                  if (mounted) {
                    Alert.error(PimFX.message(failure), context: this.context);
                  }
                }
              },
            ),
          BTN(
            name: 'به‌روزرسانی',
            icon: IconsaxPlusLinear.refresh,
            disabled: _page.loading,
            onTap: load,
          ),
        ],
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant ProductShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

Widget buildProductShopRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductShopScreen(
    business: args.required<BusinessContext>('business'),
    productId: args.required<String>('productId'),
    productName: args.required<String>('productName'),
  );
}
