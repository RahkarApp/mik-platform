import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_data/source/remote/models/pim_price.dart';
import 'package:mik_data/source/remote/models/pim_resource.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/shop.dart';

Future<bool> editShopPublication(
  BuildContext context,
  ShopFX fx,
  RemoteShop shop,
  String productId,
  String productName,
) async {
  try {
    await fx.authorize();
    await fx.restoreManagement();
    final publication = await fx.publication(shop.id, productId);
    final pim = PimFX.forContext(fx.context);
    await pim.authorize();
    final prices = pim.has('pim.price.read')
        ? (await pim.all(
            PimResource.prices,
            filters: {'productId': productId},
          )).cast<PimPrice>().where((row) => row.status == 'ACTIVE').toList()
        : <PimPrice>[];
    fx.check();
    if (!context.mounted) return false;
    return await MyBottomSheet.view(
          context,
          title: 'انتشار $productName',
          child: (scroll) => _PublicationForm(
            fx: fx,
            shop: shop,
            productId: productId,
            scroll: scroll,
            prices: prices,
            publication: publication,
          ),
        ) ==
        true;
  } catch (error) {
    if (context.mounted) Alert.error(PimFX.message(error), context: context);
    return false;
  }
}

class _PublicationForm extends StatefulWidget {
  final ShopFX fx;
  final RemoteShop shop;
  final String productId;
  final ScrollController scroll;
  final List<PimPrice> prices;
  final ({bool excluded, String? priceId, int revision}) publication;
  const _PublicationForm({
    required this.fx,
    required this.shop,
    required this.productId,
    required this.scroll,
    required this.prices,
    required this.publication,
  });
  @override
  State<_PublicationForm> createState() => _PublicationFormState();
}

class _PublicationFormController extends GetxController {
  _PublicationFormController(this.widget);
  _PublicationForm widget;
  late bool excluded = widget.publication.excluded;
  late String? priceId = widget.publication.priceId;
  bool saving = false;
}

class _PublicationFormState extends State<_PublicationForm> {
  late final _page = _PublicationFormController(widget);

  Future<void> save() async {
    if (_page.saving) return;
    {
      _page.saving = true;
      _page.update();
    }
    try {
      if (_page.priceId != null &&
          !widget.prices.any((row) => row.id == _page.priceId)) {
        throw const FormatException('Price unavailable');
      }
      await widget.fx.manage(
        ShopManagementCommand(
          ShopManagementAction.publication,
          widget.shop.id,
          {
            'expectedRevision': widget.publication.revision,
            'excluded': _page.excluded,
            'productPriceId': _page.priceId,
          },
          resourceId: widget.productId,
        ),
      );
      if (!mounted) return;
      Alert.success('تنظیمات انتشار کالا ثبت شد.');
      Get.back(result: true);
    } catch (error) {
      if (mounted) Alert.error(PimFX.message(error), context: context);
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_PublicationFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: SingleChildScrollView(
        controller: widget.scroll,
        child: Column(
          children: [
            MyDivider(text: widget.shop.name),
            Dropdown(
              name: 'انتشار کالا',
              search: false,
              items_String: const ['نمایش در فروشگاه', 'مستثنا از فروشگاه'],
              defaultValue: _page.excluded
                  ? 'مستثنا از فروشگاه'
                  : 'نمایش در فروشگاه',
              disable: _page.saving,
              onChange: (v) {
                _page.excluded = v == 'مستثنا از فروشگاه';
                _page.update();
              },
            ),
            Dropdown(
              name: 'عنوان قیمت',
              itemValue: true,
              disable: _page.saving,
              items_Value: [
                const ItemValue(text: 'قیمت پیش‌فرض محصول', data: ''),
                for (final row in widget.prices)
                  ItemValue(text: row.name, data: row.id),
              ],
              defaultValue: ItemValue(text: '', data: _page.priceId ?? ''),
              onChange: (v) {
                _page.priceId = v.data == '' ? null : v.data as String;
                _page.update();
              },
            ),
            if (_page.priceId != null &&
                !widget.prices.any((row) => row.id == _page.priceId))
              const Text(
                'عنوان قیمت فعلی دیگر فعال نیست؛ عنوان دیگری یا قیمت پیش‌فرض را انتخاب کنید.',
              ),
            const Text(
              'قابل خرید بودن کالا به وضعیت محصول، قیمت معتبر، موجودی و آماده بودن فروشگاه وابسته است.',
            ),
            if (widget.fx.managementPending != null)
              const Text(
                'یک درخواست تعیین‌تکلیف‌نشده دارید؛ از پیگیری عملیات فروشگاه استفاده کنید.',
              ),
            BTN(
              name: 'ثبت انتشار کالا',
              disabled:
                  _page.saving ||
                  widget.fx.managementPending != null ||
                  !widget.fx.has('shop.publication.update'),
              onTap: save,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant _PublicationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}
