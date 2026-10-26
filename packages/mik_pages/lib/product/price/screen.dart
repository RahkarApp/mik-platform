import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/productImage.dart';
import 'package:mik_components/elements/product_variant_options.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_utils/public/number.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import 'controller.dart';

class ProductPricesScreen extends StatefulWidget {
  final PimFX fx;
  final String productId;
  const ProductPricesScreen({
    super.key,
    required this.fx,
    required this.productId,
  });
  @override
  State<ProductPricesScreen> createState() => _ProductPricesScreenState();
}

class _ProductPricesScreenController extends GetxController {
  _ProductPricesScreenController(this.widget);
  ProductPricesScreen widget;
  late final c = ProductPriceController(widget.fx, widget.productId);
  int currentIndex = 0;
  Worker? readErrors;
}

class _ProductPricesScreenState extends State<ProductPricesScreen> {
  late final _page = _ProductPricesScreenController(widget);

  @override
  void initState() {
    super.initState();
    _page.readErrors = everAll(
      [_page.c.loadError, _page.c.variantsError, _page.c.metadataError],
      (_) {
        final message =
            _page.c.loadError.value ??
            _page.c.variantsError.value ??
            _page.c.metadataError.value;
        if (mounted && message != null) Alert.error(message, context: context);
      },
    );
  }

  @override
  void dispose() {
    _page.readErrors?.dispose();
    super.dispose();
  }

  Future<void> edit({
    PimRecord? item,
    bool isOverride = false,
    String? priceId,
    String? variantId,
  }) async {
    _page.c.error.value = null;
    _page.c.conflict.value = false;
    await MyBottomSheet.view(
      context,
      title: isOverride
          ? 'قیمت اختصاصی تنوع'
          : item == null
          ? 'افزودن قیمت جدید'
          : 'ویرایش قیمت ${(item as PimPrice).name}',
      isDismissible: false,
      child: (scroll) => ProductPriceForm(
        controller: _page.c,
        item: item,
        isOverride: isOverride,
        embedded: true,
        initialPriceId: priceId,
        initialVariantId: variantId,
      ),
    );
    if (mounted) {
      _page.c.conflict.value = false;
      await _page.c.load();
    }
  }

  Future<void> resume() async {
    await _page.c.resume();
    if (!mounted) return;
    if (_page.c.error.value != null) {
      Alert.error(_page.c.error.value!, context: context);
    } else if (_page.c.pending.value == null) {
      Alert.success('درخواست قیمت با موفقیت تأیید شد.');
    }
  }

  void archive(PimRecord item) {
    Confirm.con(
      context,
      type: ConfirmType.DELETE,
      confirmText: 'تایید و حذف',
      subtext: 'این قیمت از استفاده خارج و در سرور آرشیو می‌شود.',
      onTapConfirm: () async {
        Get.back();
        try {
          if (await _page.c.save(_page.c.archiveCommand(item))) {
            if (mounted) Alert.success('قیمت با موفقیت آرشیو شد.');
            await _page.c.load();
          } else if (mounted && _page.c.error.value != null) {
            Alert.error(_page.c.error.value!, context: context);
          }
        } catch (failure) {
          if (mounted) Alert.error(_page.c.message(failure), context: context);
        }
      },
    );
  }

  Widget priceItem(PimPrice price) => Column(
    children: [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: price.isDefault
                    ? AppColors.secondary
                    : AppColors.boxBackground,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(
                IconsaxPlusLinear.money,
                size: 25,
                color: price.isDefault ? Colors.white : AppColors.disable,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${Number.addCommas(price.amount)} تومان',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (price.status == 'ARCHIVED')
                    const Text('آرشیو', style: TextStyle(fontSize: 11)),
                  if (price.validFrom != null || price.validUntil != null)
                    Text(
                      '${_displayDate(price.validFrom)} تا ${_displayDate(price.validUntil)}',
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
            if (_page.c.canEdit(price) && _page.c.pending.value == null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  key: ValueKey('edit-price-${price.id}'),
                  onTap: () {
                    edit(item: price);
                  },
                  child: const Icon(IconsaxPlusLinear.edit),
                ),
              ),
            if (_page.c.canArchive(price) && _page.c.pending.value == null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  key: ValueKey('archive-price-${price.id}'),
                  onTap: () => archive(price),
                  child: const Icon(IconsaxPlusLinear.trash_square),
                ),
              ),
            const SizedBox(width: 10),
          ],
        ),
      ),
      EndLine(),
    ],
  );
  Widget variantItem(PimVariant variant) {
    final specific =
        _page.c.overrides
            .where((o) => o.variantId == variant.id && o.status == 'ACTIVE')
            .map((o) => o.amount)
            .toList()
          ..sort();
    return ExpansionTile(
      key: PageStorageKey('price-variant-${variant.id}'),
      shape: const Border(bottom: BorderSide(color: Colors.grey)),
      collapsedShape: const Border(bottom: BorderSide(color: Colors.grey)),
      title: ProductVariantOptions(
        variant: variant,
        attributes: _page.c.attributes,
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('قیمت فروش:', style: TextStyle(fontSize: 11)),
          Flexible(
            child: Text(
              specific.isEmpty
                  ? 'پیش‌فرض'
                  : specific.first == specific.last
                  ? Price.showWithCurrency(specific.first)
                  : '${Price.show(specific.first)} - ${Price.showWithCurrency(specific.last)}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
      children: [
        for (final price in _page.c.prices) variantPrice(variant, price),
      ],
    );
  }

  Widget variantPrice(PimVariant variant, PimPrice price) {
    final value = _page.c.overrides
        .where((o) => o.productPriceId == price.id && o.variantId == variant.id)
        .firstOrNull;
    final writable =
        _page.c.pending.value == null &&
        price.status == 'ACTIVE' &&
        (value == null
            ? _page.c.canCreate && variant.status == 'ACTIVE'
            : _page.c.canEdit(value));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Icon(IconsaxPlusLinear.dollar_square, color: Colors.grey),
              const SizedBox(width: 5),
              Expanded(
                child: Text(price.name, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value == null
                      ? 'تعیین نشده'
                      : '${Price.showWithCurrency(value.amount)}${value.status == 'ARCHIVED' ? ' (آرشیو)' : ''}',
                  style: TextStyle(fontSize: value == null ? 10 : 13),
                ),
              ),
              if (writable)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    key: ValueKey('variant-price-${variant.id}-${price.id}'),
                    onTap: () {
                      edit(
                        item: value,
                        isOverride: true,
                        priceId: price.id,
                        variantId: variant.id,
                      );
                    },
                    child: const Icon(IconsaxPlusLinear.edit),
                  ),
                ),
              if (value != null &&
                  _page.c.pending.value == null &&
                  _page.c.canArchive(value))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => archive(value),
                    child: const Icon(IconsaxPlusLinear.trash_square),
                  ),
                ),
            ],
          ),
        ),
        EndLine(rightPadding: 20),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ProductPricesScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      header: Header.page(context, text: 'قیمت‌گذاری محصول', help: false),
      initState: () async {
        await _page.c.load();
        return true;
      },
      child: (_) => Obx(() {
        if (_page.c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_page.c.loadError.value != null) {
          return ErrorSection(_page.c.loadError.value, act: _page.c.load);
        }
        final product = _page.c.product!;
        final categories = _page.c.categories
            .where((row) => product.categoryIds.contains(row.id))
            .map((row) => row.name)
            .join('، ');
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  ProductImage.img(
                    context,
                    product,
                    90,
                    showAll: true,
                    business: _page.c.fx.context,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.variantAxes.isNotEmpty)
                          Icon(
                            IconsaxPlusLinear.star,
                            size: 15,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                        Text(
                          product.name,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          categories.isEmpty
                              ? 'دسته‌بندی در دسترس نیست'
                              : categories,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_page.c.pending.value != null) ...[
                const Text(
                  'یک درخواست تعیین‌تکلیف‌نشده وجود دارد؛ تا روشن شدن نتیجه، ثبت تازه انجام نمی‌شود.',
                ),
                if (_page.c.pendingHere)
                  BTN(
                    name: 'تلاش مجدد همان درخواست قیمت',
                    icon: IconsaxPlusLinear.refresh,
                    onTap: resume,
                    disabled: _page.c.saving.value,
                  )
                else
                  const Text(
                    'درخواست باز مربوط به عملیات دیگری است؛ آن را در صفحهٔ مربوط ادامه دهید.',
                  ),
              ],
              if (_page.c.error.value != null) Text(_page.c.error.value!),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: darkMode.value
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_page.c.variants.any(
                              (v) => v.optionValues.isNotEmpty,
                            ) ||
                            _page.c.product!.variantAxes.isNotEmpty)
                          MyTabBar(
                            tabs: const ['قیمت‌گذاری اصلی', 'بر اساس ویژگی'],
                            currentIndex: _page.currentIndex,
                            bgColor: darkMode.value
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            divider: false,
                            index: (i) {
                              _page.currentIndex = i;
                              _page.update();
                            },
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _page.c.load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                if (_page.currentIndex == 0) ...[
                                  if (_page.c.prices.isEmpty)
                                    EmptyList(
                                      text: 'هیچ قیمتی تعریف نکردید!',
                                      icon: IconsaxPlusLinear.money,
                                    ),
                                  for (final price in _page.c.prices)
                                    priceItem(price),
                                  if (_page.c.canCreate &&
                                      _page.c.pending.value == null)
                                    BTN(
                                      name: 'افزودن قیمت جدید',
                                      onTap: () {
                                        edit();
                                      },
                                    ),
                                ] else ...[
                                  if (_page.c.variantsError.value != null)
                                    Text(_page.c.variantsError.value!),
                                  for (final variant in _page.c.variants)
                                    variantItem(variant),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    ),
  );

  @override
  void didUpdateWidget(covariant ProductPricesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

String _displayDate(DateTime? value) {
  if (value == null) return 'بدون محدودیت';
  final local = value.toLocal();
  try {
    final date = Jalali.fromDateTime(local);
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    // Keep server dates visible when they exceed the Persian calendar library's range.
    return value.toUtc().toIso8601String();
  }
}

class ProductPriceForm extends StatefulWidget {
  final ProductPriceController controller;
  final PimRecord? item;
  final bool isOverride, embedded;
  final String? initialPriceId, initialVariantId;
  const ProductPriceForm({
    super.key,
    required this.controller,
    this.item,
    this.isOverride = false,
    this.embedded = false,
    this.initialPriceId,
    this.initialVariantId,
  });
  @override
  State<ProductPriceForm> createState() => _ProductPriceFormState();
}

class _ProductPriceFormController extends GetxController {
  PimRecord? item;
  final name = TextEditingController(),
      amount = TextEditingController(),
      start = TextEditingController(),
      end = TextEditingController();
  final defaultValue = 'خیر'.obs,
      priceId = RxnString(),
      variantId = RxnString();
  DateTime? from, until;
  String? dateError;
  final localError = RxnString();
}

class _ProductPriceFormState extends State<ProductPriceForm> {
  late final _page = _ProductPriceFormController();

  ProductPriceController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    fill(widget.item);
    _page.priceId.value ??= widget.initialPriceId;
    _page.variantId.value ??= widget.initialVariantId;
  }

  void fill(PimRecord? value) {
    _page.item = value;
    if (value is PimPrice) {
      _page.name.text = value.name;
      _page.amount.text = '${value.amount} تومان';
      _page.defaultValue.value = value.isDefault ? 'بله' : 'خیر';
      _page.from = value.validFrom;
      _page.until = value.validUntil;
    } else if (value is PimPriceOverride) {
      _page.amount.text = '${value.amount} تومان';
      _page.priceId.value = value.productPriceId;
      _page.variantId.value = value.variantId;
    }
    _page.start.text = _page.from == null ? '' : _displayDate(_page.from);
    _page.end.text = _page.until == null ? '' : _displayDate(_page.until);
    _page.dateError = null;
    _page.localError.value = null;
  }

  void dateChanged(String text, bool isStart) {
    try {
      final parts = text.toEnglishDigit().split(' ');
      if (parts.length != 2) {
        throw const FormatException('Choose date and time');
      }
      final date = parts[0].split('/').map(int.parse).toList(),
          time = parts[1].split(':').map(int.parse).toList();
      if (date.length != 3 ||
          time.length != 2 ||
          time[0] > 23 ||
          time[1] > 59) {
        throw const FormatException('Invalid time');
      }
      final gregorian = Jalali(date[0], date[1], date[2]).toDateTime();
      final value = DateTime(
        gregorian.year,
        gregorian.month,
        gregorian.day,
        time[0],
        time[1],
      );
      if (isStart) {
        _page.from = value;
      } else {
        _page.until = value;
      }
      _page.dateError = null;
      _page.localError.value = null;
    } catch (_) {
      _page.dateError = 'تاریخ و ساعت را کامل انتخاب کنید.';
      _page.localError.value = _page.dateError;
    }
  }

  Future<void> reload() async {
    final id = _page.item?.id;
    await c.load();
    if (!mounted || c.loadError.value != null) return;
    final value = widget.isOverride
        ? c.overrides.where((p) => p.id == id).firstOrNull
        : c.prices.where((p) => p.id == id).firstOrNull;
    if (value == null) {
      _page.localError.value = 'قیمت دیگر در دسترس نیست.';
      return;
    }
    {
      fill(value);
      _page.update();
    }
    c.conflict.value = false;
  }

  Future<void> save() async {
    _page.localError.value = null;
    try {
      if (_page.dateError != null) throw StateError(_page.dateError!);
      final command = widget.isOverride
          ? c.overrideCommand(
              item: _page.item as PimPriceOverride?,
              priceId: _page.priceId.value ?? '',
              variantId: _page.variantId.value ?? '',
              input: _page.amount.text,
            )
          : c.priceCommand(
              item: _page.item as PimPrice?,
              name: _page.name.text,
              input: _page.amount.text,
              isDefault: _page.defaultValue.value == 'بله',
              from: _page.from,
              until: _page.until,
            );
      final unchanged =
          command.operation == 'update' &&
          command.body.keys.every((key) => key == 'expectedRevision');
      if (await c.save(command) && mounted) {
        if (unchanged) {
          Alert.info('تغییری در قیمت داده نشده است.');
        } else {
          Alert.success('قیمت با موفقیت ثبت شد.');
        }
        Get.back(result: true);
      } else if (mounted && c.error.value != null) {
        Alert.error(c.error.value!, context: context);
      }
    } catch (failure) {
      _page.localError.value = c.message(failure);
      if (mounted) Alert.error(_page.localError.value!, context: context);
    }
  }

  @override
  void dispose() {
    for (final ctl in [_page.name, _page.amount, _page.start, _page.end]) {
      ctl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_ProductPriceFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !c.saving.value,
        child: widget.embedded
            ? editor()
            : Main(
                header: Header.page(
                  context,
                  text: widget.isOverride ? 'قیمت اختصاصی تنوع' : 'عنوان قیمت',
                  help: false,
                ),
                initState: () async => true,
                child: (_) => editor(),
              ),
      ),
    ),
  );

  Widget editor() => Obx(() {
    final titles = [
      for (final price in c.prices.where((p) => p.status == 'ACTIVE'))
        ItemValue(text: price.name, data: price.id),
    ];
    final variants = [
      for (final variant in c.variants.where((v) => v.status == 'ACTIVE'))
        ItemValue(text: c.variantName(variant), data: variant.id),
    ];
    final fields = <Widget>[
      AbsorbPointer(
        absorbing:
            c.saving.value || c.pending.value != null || c.conflict.value,
        child: Column(
          children: [
            MyDivider(text: widget.isOverride ? 'قیمت تنوع' : 'اطلاعات قیمت'),
            if (widget.isOverride) ...[
              if (_page.item == null &&
                  (widget.initialPriceId == null ||
                      widget.initialVariantId == null)) ...[
                Dropdown(
                  name: 'عنوان قیمت',
                  itemValue: true,
                  items_Value: titles,
                  defaultValue: titles
                      .where((p) => p.data == _page.priceId.value)
                      .firstOrNull,
                  onChange: (value) =>
                      _page.priceId.value = (value as ItemValue).data as String,
                ),
                Dropdown(
                  name: 'تنوع',
                  itemValue: true,
                  items_Value: variants,
                  defaultValue: variants
                      .where((v) => v.data == _page.variantId.value)
                      .firstOrNull,
                  onChange: (value) => _page.variantId.value =
                      (value as ItemValue).data as String,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '${c.prices.where((p) => p.id == _page.priceId.value).firstOrNull?.name ?? 'عنوان قیمت'} · ${c.variants.where((v) => v.id == _page.variantId.value).map(c.variantName).firstOrNull ?? 'تنوع در دسترس نیست'}',
                  ),
                ),
            ],
            PriceInput(
              key: const ValueKey('price-amount'),
              controller: _page.amount,
              name: 'قیمت',
              currency: 'تومان',
              require: true,
            ),
            if (!widget.isOverride)
              Input(
                key: const ValueKey('price-name'),
                controller: _page.name,
                name: 'نام قیمت',
                require: true,
                maxLength: 200,
              ),
            if (!widget.isOverride) ...[
              if (!(_page.item is PimPrice &&
                  (_page.item as PimPrice).isDefault))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('قیمت پیش‌فرض:'),
                      MyTab(
                        width: false,
                        widthSize: 90,
                        color: AppColors.secondary,
                        tab: const ['بله', 'خیر'],
                        value: _page.defaultValue,
                        enabledValues: c.canDefault
                            ? null
                            : {_page.defaultValue.value},
                        callback: (value) => _page.defaultValue.value = value,
                      ),
                    ],
                  ),
                ),
              if (c.prices
                      .where((p) => p.isDefault && p.status == 'ACTIVE')
                      .firstOrNull
                  case final current?)
                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _page.item?.id == current.id
                        ? AppColors.secondary
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    border: _page.item?.id == current.id
                        ? null
                        : Border.all(color: Colors.grey),
                  ),
                  child: Text(
                    _page.item?.id == current.id
                        ? 'قیمت پیش‌فرض'
                        : 'پیش‌فرض فعلی: ${current.name} - ${Price.showWithCurrency(current.amount)}',
                    style: TextStyle(
                      color: _page.item?.id == current.id ? Colors.white : null,
                      fontWeight: _page.item?.id == current.id
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                ),
              ExpansionTile(
                key: const ValueKey('price-validity'),
                title: const Text('اعتبار قیمت'),
                children: [
                  MyDivider(text: 'اعتبار قیمت (ساعت محلی دستگاه)'),
                  DateInput(
                    controller: _page.start,
                    name: 'شروع اعتبار',
                    timePicker: true,
                    firstDate: Jalali.fromDateTime(DateTime(1970)),
                    lastDate: Jalali.max,
                    onChanged: (value) => dateChanged(value as String, true),
                  ),
                  MiniBTN(
                    name: 'پاک کردن شروع اعتبار',
                    noFlex: true,
                    height: 40,
                    icon: IconsaxPlusLinear.close_square,
                    onTap: () {
                      _page.start.clear();
                      _page.from = null;
                      _page.dateError = null;
                      _page.localError.value = null;
                    },
                  ),
                  DateInput(
                    controller: _page.end,
                    name: 'پایان اعتبار',
                    timePicker: true,
                    firstDate: Jalali.fromDateTime(DateTime(1970)),
                    lastDate: Jalali.max,
                    onChanged: (value) => dateChanged(value as String, false),
                  ),
                  MiniBTN(
                    name: 'پاک کردن پایان اعتبار',
                    noFlex: true,
                    height: 40,
                    icon: IconsaxPlusLinear.close_square,
                    onTap: () {
                      _page.end.clear();
                      _page.until = null;
                      _page.dateError = null;
                      _page.localError.value = null;
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      if (_page.localError.value != null || c.error.value != null)
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(_page.localError.value ?? c.error.value!),
        ),
      if (c.loadError.value != null) Text(c.loadError.value!),
      if (c.conflict.value)
        BTN(name: 'دریافت نسخه جدید و جایگزینی فرم', onTap: reload)
      else if (c.pending.value != null)
        BTN(
          name: 'تلاش مجدد همان درخواست قیمت',
          disabled: c.saving.value,
          onTap: () async {
            if (await c.save(c.pending.value!) && mounted) {
              Get.back(result: true);
            }
          },
        )
      else
        Row(
          children: [
            Expanded(
              flex: 3,
              child: BTN(
                name: _page.item == null ? 'ثبت قیمت' : 'ویرایش قیمت',
                disabled: c.saving.value,
                onTap: save,
              ),
            ),
            Expanded(
              child: BTN(
                name: 'انصراف',
                borderOnly: true,
                disabled: c.saving.value,
                onTap: () => Get.back(),
              ),
            ),
          ],
        ),
    ];
    return widget.embedded
        // The native fit-to-content sheet already owns the scroll view.
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: fields),
          )
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: fields,
          );
  });
}

Widget buildProductPricesRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductPricesScreen(
    fx: args.required<PimFX>('fx'),
    productId: args.required<String>('productId'),
  );
}
