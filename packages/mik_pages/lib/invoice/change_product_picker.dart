import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';

import 'selection_sheet.dart';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/invoice_change.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/warehouse_management.dart';
import 'package:uuid/uuid.dart';

class InvoiceChangeProductPicker extends StatefulWidget {
  final InvoiceChangeFX fx;
  final Set<String> existing;
  const InvoiceChangeProductPicker({
    required this.fx,
    required this.existing,
    super.key,
  });
  @override
  State<InvoiceChangeProductPicker> createState() =>
      _InvoiceChangeProductPickerState();
}

class _InvoiceChangeProductPickerController extends GetxController {
  final search = TextEditingController();
  List<PimProduct> products = [];
  List<PimVariant> variants = [];
  List<PimPrice> prices = [];
  List<BusinessWarehouse> warehouses = [];
  PimProduct? product;
  String query = '';
  String? warehouseId, error;
  bool loading = true;
}

class _InvoiceChangeProductPickerState
    extends State<InvoiceChangeProductPicker> {
  late final _page = _InvoiceChangeProductPickerController();

  late final pim = PimFX.forContext(widget.fx.context);

  bool get purchase => widget.fx.invoice.type == 'PURCHASE';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page.search.dispose();
    super.dispose();
  }

  void fail(Object failure) {
    _page.error = PimFX.message(failure);
    Alert.error(_page.error!, context: context);
  }

  Future<Object> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.update();
    }
    try {
      widget.fx.check();
      await widget.fx.authorize();
      if (!widget.fx.allowed('amend')) {
        throw const FormatException('Amend permission unavailable');
      }
      await pim.authorize();
      final rows = (await pim.all(
        PimResource.products,
        filters: {'status': 'ACTIVE'},
      )).cast<PimProduct>();
      // A proforma has no stock effect; a default warehouse is not a prerequisite.
      if (widget.fx.invoice.type != 'PROFORMA') {
        final warehouseFx = WarehouseManagementFX.forContext(widget.fx.context);
        final branch = await warehouseFx.branch();
        if (purchase) {
          final allowed = <BusinessWarehouse>[];
          for (final row in await warehouseFx.warehouses()) {
            if (row.status == 'ACTIVE' &&
                await warehouseFx.canReceive(row.warehouseId)) {
              allowed.add(row);
            }
          }
          _page.warehouses = allowed;
        } else {
          _page.warehouseId = branch.defaultWarehouseId;
        }
      }
      widget.fx.check();
      if (mounted) {
        _page.products = rows;
        _page.update();
      }
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<void> open(PimProduct row) async {
    {
      _page.loading = true;
      _page.error = null;
      _page.variants = [];
      _page.prices = [];
      _page.update();
    }
    try {
      widget.fx.check();
      final options = (await pim.all(
        PimResource.variants,
        filters: {'productId': row.id, 'status': 'ACTIVE'},
      )).cast<PimVariant>();
      final titles = purchase
          ? <PimPrice>[]
          : (await pim.all(
              PimResource.prices,
              filters: {'productId': row.id, 'status': 'ACTIVE'},
            )).cast<PimPrice>();
      if (options.any((v) => v.productId != row.id) ||
          titles.any((p) => p.productId != row.id)) {
        throw const FormatException('Unexpected product options');
      }
      widget.fx.check();
      if (mounted) {
        {
          _page.product = row;
          _page.variants = options;
          _page.prices = titles;
          _page.update();
        }
      }
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> choose(PimVariant variant, {PimPrice? price}) async {
    if (_page.loading) return;
    if (widget.existing.contains(variant.id)) {
      Alert.error(
        'این تنوع در فاکتور وجود دارد؛ تعداد همان ردیف را اصلاح کنید.',
        context: context,
      );
      return;
    }
    if (_page.warehouseId == null && widget.fx.invoice.type != 'PROFORMA') {
      Alert.error(
        purchase
            ? 'انبار مجاز ورود کالا را انتخاب کنید.'
            : 'ابتدا انبار پیش‌فرض شعبه را مشخص کنید.',
        context: context,
      );
      return;
    }
    {
      _page.loading = true;
      _page.update();
    }
    try {
      widget.fx.check();
      final effective = purchase
          ? null
          : await pim.effectivePrice(variant.id, priceId: price!.id);
      if (effective != null && effective.productId != _page.product!.id) {
        throw const FormatException('Unexpected selected price');
      }
      widget.fx.check();
      if (!mounted) return;
      Get.back(
        result: <String, dynamic>{
        'lineId': const Uuid().v4(),
        'variantId': variant.id,
        'name': _page.product!.name,
        'quantity': '1',
        'discountAmount': 0,
        if (_page.warehouseId != null) 'warehouseIds': [_page.warehouseId!],
        if (effective != null) ...{
          'productPriceId': effective.productPriceId,
          'unitPrice': effective.amount,
        },
      });
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_InvoiceChangeProductPickerController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(context, text: 'افزودن کالا به فاکتور'),
      child: (_) => Column(
        children: [
          MySearchBar(
            controller: _page.search,
            type: SearchBarType.product,
            enableScanner: false,
            callback: (value) {
              _page.query = value.toString().trim();
              _page.update();
            },
          ),
          if (_page.loading) const LinearProgressIndicator(),
          if (_page.error != null)
            Text(_page.error!, textAlign: TextAlign.center),
          MiniBTN(
            name: 'دریافت مجدد کالاها',
            icon: IconsaxPlusLinear.refresh,
            noFlex: true,
            onTap: _page.loading ? null : load,
          ),
          if (_page.product != null)
            MiniBTN(
              name: 'بازگشت به محصولات',
              icon: IconsaxPlusLinear.arrow_right,
              noFlex: true,
              onTap: _page.loading
                  ? null
                  : () {
                      _page.product = null;
                      _page.update();
                    },
            ),
          Expanded(
            child: ListView(
              children: [
                if (purchase) ...[
                  MyDivider(text: 'انبار ورود کالای جدید'),
                  if (_page.warehouses.isEmpty && !_page.loading)
                    const Text('انبار مجاز ورود کالا دریافت نشد.'),
                  MiniBTN(
                    name:
                        _page.warehouses
                            .where(
                              (row) => row.warehouseId == _page.warehouseId,
                            )
                            .firstOrNull
                            ?.name ??
                        'انتخاب انبار مقصد',
                    icon: IconsaxPlusLinear.box,
                    noFlex: true,
                    onTap: _page.loading
                        ? null
                        : () async {
                            final selected = await selectInvoiceWarehouse(
                              context,
                              warehouses: _page.warehouses,
                              branchName:
                                  widget.fx.context.selectedBranch?.name ?? '',
                              selectedId: _page.warehouseId,
                            );
                            if (!mounted || selected == null) return;
                            try {
                              widget.fx.check();
                              {
                                _page.warehouseId = selected.warehouseId;
                                _page.update();
                              }
                            } catch (failure) {
                              fail(failure);
                            }
                          },
                  ),
                ],
                if (_page.product == null) ...[
                  if (_page.products
                          .where((p) => p.name.contains(_page.query))
                          .isEmpty &&
                      !_page.loading)
                    const Text('محصولی یافت نشد.'),
                  for (final row in _page.products.where(
                    (p) => p.name.contains(_page.query),
                  ))
                    MiniBTN(
                      name: row.name,
                      icon: IconsaxPlusLinear.box,
                      noFlex: true,
                      onTap: _page.loading ? null : () => open(row),
                    ),
                ] else ...[
                  MyDivider(text: _page.product!.name),
                  for (final (index, variant) in _page.variants.indexed) ...[
                    Text(variant.sku ?? 'تنوع ${index + 1}'),
                    if (widget.existing.contains(variant.id))
                      const Text('در فاکتور وجود دارد.')
                    else if (purchase)
                      MiniBTN(
                        name: 'انتخاب تنوع ${index + 1}',
                        icon: IconsaxPlusLinear.add,
                        noFlex: true,
                        onTap: _page.loading ? null : () => choose(variant),
                      )
                    else
                      for (final price in _page.prices)
                        MiniBTN(
                          name: price.name,
                          icon: IconsaxPlusLinear.money,
                          noFlex: true,
                          onTap: _page.loading
                              ? null
                              : () => choose(variant, price: price),
                        ),
                    MyDivider(),
                  ],
                  if (!purchase && _page.prices.isEmpty && !_page.loading)
                    const Text('عنوان قیمت فعالی برای انتخاب دریافت نشد.'),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildInvoiceChangeProductPickerRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return InvoiceChangeProductPicker(
    fx: args.required<InvoiceChangeFX>('fx'),
    existing: args.required<Set<String>>('existing'),
  );
}
