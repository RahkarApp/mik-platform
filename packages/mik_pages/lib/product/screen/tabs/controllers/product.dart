import 'package:mik_data/utils/fx/realtime.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/CatInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/product_facts.dart';

class ProductTabDashboardController extends GetxController {
  static const statuses = <String, String?>{
    'همه': null,
    'فعال': 'ACTIVE',
    'پیش‌نویس': 'DRAFT',
    'آرشیو': 'ARCHIVED',
  };
  final prd = <PimProduct>[].obs;
  final categories = <PimCategory>[].obs;
  final brands = <PimBrand>[].obs;
  final brandId = RxnString();
  final categoryError = RxnString(), brandError = RxnString();
  bool get canFilterCategories =>
      categoryError.value == null &&
      _fx?.has('pim.product.category.read') == true;
  bool get canFilterBrands =>
      brandError.value == null && _fx?.has('pim.brand.read') == true;
  final loading = false.obs, loadingMore = false.obs, hasMore = false.obs;
  final error = RxnString(), moreError = RxnString();
  final filtered = false.obs;
  final typeFilter = 'فعال'.obs, prFilter = 'همه'.obs;
  final filteredCat = <Map<String, String>>[].obs;
  final filteredCatId = <String>[].obs;
  PimFX? _fx;
  ProductFactsFX? _facts;
  ProductFactsFX? get facts => valid ? _facts : null;
  RealtimeWatch? _realtime;
  bool _attached = false;
  int _generation = 0;
  Timer? _debounce;
  String _query = '';
  String? _cursor;
  final _cursors = <String>{}, _ids = <String>{};

  bool get canCreate =>
      loading.isFalse && valid && _fx?.has('pim.product.create') == true;

  bool get valid => _attached && _fx?.context.valid == true;
  String _normalize(String text) =>
      text.replaceAll(' ', '').toLowerCase().toEnglishDigit();
  String get _search => _query.trim().length < 2 ? '' : _normalize(_query);
  bool get _scanPages => _search.isNotEmpty || filteredCatId.length > 1;

  Future<void> attach(String appId, {String query = ''}) async {
    final previous = _fx?.context;
    detach();
    final context = BusinessContext.forApp(appId);
    _fx = context == null ? null : PimFX.forContext(context);
    _attached = true;
    _query = query;
    if (!identical(previous, context)) {
      typeFilter.value = 'فعال';
      prFilter.value = 'همه';
      filteredCat.clear();
      filteredCatId.clear();
      brandId.value = null;
      filtered.value = false;
    }
    if (context != null) {
      _realtime = RealtimeWatch(
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
        () => init(keepPages: true, background: true),
        invalidate: () {
          _generation++;
          _facts = null;
          prd.clear();
          categories.clear();
          brands.clear();
        },
      );
    }
    await init();
  }

  void detach() {
    _realtime?.dispose();
    _realtime = null;
    _generation++;
    _attached = false;
    _debounce?.cancel();
    prd.clear();
    categories.clear();
    brands.clear();
    categoryError.value = null;
    brandError.value = null;
    loading.value = false;
    loadingMore.value = false;
    hasMore.value = false;
    error.value = null;
    moreError.value = null;
  }

  void search(Object? value) {
    if (!_attached || value == null || value == '-1') return;
    _query = value.toString();
    _generation++;
    prd.clear();
    hasMore.value = false;
    loadingMore.value = false;
    loading.value = true;
    error.value = null;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(authorize: false),
    );
  }

  Future<void> init({bool keepPages = false, bool background = false}) async {
    _debounce?.cancel();
    if (!_attached) return;
    await _load(
      authorize: true,
      minimum: keepPages ? _ids.length : 0,
      background: background,
    );
  }

  Future<void> _load({
    required bool authorize,
    int minimum = 0,
    bool background = false,
  }) async {
    final generation = ++_generation;
    final fx = _fx;
    final refreshed = background ? <PimProduct>[] : null;
    if (!background) prd.clear();
    _cursor = null;
    _cursors.clear();
    _ids.clear();
    hasMore.value = false;
    if (!background) loading.value = true;
    loadingMore.value = false;
    error.value = null;
    moreError.value = null;
    _facts = fx == null ? null : ProductFactsFX(fx);
    filtered.value =
        typeFilter.value != 'فعال' ||
        prFilter.value != 'همه' ||
        filteredCatId.isNotEmpty ||
        brandId.value != null;
    try {
      if (fx == null) throw const AuthError(401, 'SESSION_INVALID');
      fx.context.check();
      if (prFilter.value != 'همه' || !statuses.containsKey(typeFilter.value)) {
        throw StateError(
          'فیلتر نوع و موجودی فعلاً در دسترس نیست؛ فیلترها را پاک کنید.',
        );
      }
      if (authorize) {
        if (!background) {
          categories.clear();
          brands.clear();
        }
        categoryError.value = null;
        brandError.value = null;
        await fx.authorize();
        if (generation != _generation) return;
        fx.require('pim.product.read');
        // Optional filter labels must not hide products or erase the selected IDs on failure.
        if (fx.has('pim.product.category.read')) {
          try {
            final rows = (await fx.all(PimResource.categories))
                .cast<PimCategory>();
            if (generation != _generation) return;
            if (rows.any((v) => !['ACTIVE', 'ARCHIVED'].contains(v.status)) ||
                rows.map((v) => v.id).toSet().length != rows.length) {
              throw const FormatException('Unexpected filter categories');
            }
            categories.assignAll(rows);
          } catch (failure) {
            if (generation != _generation) return;
            if (!fx.context.valid ||
                failure is AuthError && failure.requiresLogin) {
              rethrow;
            }
            categoryError.value = PimFX.message(failure);
          }
        }
        if (fx.has('pim.brand.read')) {
          try {
            final rows = (await fx.all(PimResource.brands)).cast<PimBrand>();
            if (generation != _generation) return;
            if (rows.any((v) => !['ACTIVE', 'ARCHIVED'].contains(v.status)) ||
                rows.map((v) => v.id).toSet().length != rows.length) {
              throw const FormatException('Unexpected filter brands');
            }
            brands.assignAll(rows);
          } catch (failure) {
            if (generation != _generation) return;
            if (!fx.context.valid ||
                failure is AuthError && failure.requiresLogin) {
              rethrow;
            }
            brandError.value = PimFX.message(failure);
          }
        }
      }
      await _append(fx, generation, target: refreshed);
      // The server has no name-search filter. Search must cover every cursor page.
      while ((_scanPages || _ids.length < minimum) &&
          hasMore.isTrue &&
          generation == _generation) {
        await _append(fx, generation, target: refreshed);
      }
      if (generation == _generation && refreshed != null) {
        prd.assignAll(refreshed);
      }
    } catch (failure) {
      if (generation != _generation) return;
      prd.clear();
      hasMore.value = false;
      error.value = failure is StateError
          ? failure.message.toString()
          : PimFX.message(failure);
    } finally {
      if (generation == _generation) loading.value = false;
    }
  }

  Future<void> _append(
    PimFX fx,
    int generation, {
    List<PimProduct>? target,
  }) async {
    final page = await fx.page(
      PimResource.products,
      after: _cursor,
      filters: {
        if (statuses[typeFilter.value] != null)
          'status': statuses[typeFilter.value]!,
        if (brandId.value != null) 'brandId': brandId.value!,
        if (filteredCatId.length == 1) 'categoryId': filteredCatId.single,
      },
    );
    if (generation != _generation) return;
    final rows = page.items.cast<PimProduct>();
    final expectedStatus = statuses[typeFilter.value];
    if (rows.any(
      (row) =>
          !['DRAFT', 'ACTIVE', 'ARCHIVED'].contains(row.status) ||
          expectedStatus != null && row.status != expectedStatus ||
          brandId.value != null && row.brandId != brandId.value ||
          filteredCatId.length == 1 &&
              !row.categoryIds.contains(filteredCatId.single),
    )) {
      throw const FormatException('Unexpected product filters');
    }
    if (page.nextCursor != null && _cursors.contains(page.nextCursor) ||
        rows.any((row) => _ids.contains(row.id)) ||
        rows.map((row) => row.id).toSet().length != rows.length) {
      throw const FormatException('Repeated product page');
    }
    if (page.nextCursor != null) _cursors.add(page.nextCursor!);
    _ids.addAll(rows.map((row) => row.id));
    (target ?? prd).addAll(
      rows.where(
        (row) =>
            (filteredCatId.isEmpty ||
                row.categoryIds.any(filteredCatId.contains)) &&
            (_search.isEmpty ||
                [
                  row.name,
                  row.id,
                  row.slug,
                  row.model ?? '',
                ].any((text) => _normalize(text).contains(_search))),
      ),
    );
    _cursor = page.nextCursor;
    hasMore.value = _cursor != null;
  }

  Future<void> loadMore() async {
    final fx = _fx;
    if (!_attached ||
        fx == null ||
        loading.isTrue ||
        loadingMore.isTrue ||
        hasMore.isFalse) {
      return;
    }
    final generation = _generation;
    loadingMore.value = true;
    moreError.value = null;
    try {
      await _append(fx, generation);
    } catch (failure) {
      if (generation != _generation) return;
      if (!fx.context.valid ||
          failure is FormatException ||
          failure is AuthError &&
              (failure.statusCode == 403 || failure.requiresLogin)) {
        prd.clear();
        hasMore.value = false;
        error.value = PimFX.message(failure);
      } else {
        moreError.value = PimFX.message(failure);
      }
    } finally {
      if (generation == _generation) loadingMore.value = false;
    }
  }

  String categoryNames(PimProduct item) {
    final names = {
      for (final category in categories) category.id: category.name,
    };
    return item.categoryIds.map((id) => names[id] ?? '—').join('، ');
  }

  @override
  void onClose() {
    detach();
    super.onClose();
  }

  Future<void> resetFilters() async {
    prFilter.value = 'همه';
    typeFilter.value = 'فعال';
    filteredCat.clear();
    filteredCatId.clear();
    brandId.value = null;
    await init();
  }

  Future<void> filter(BuildContext context) async {
    final categoryController = TextEditingController();
    await MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          MyTab(
            tab: const ['همه', 'کالا', 'خدمات'],
            enabledValues: const {'همه'},
            color: AppColors.primaryLite,
            value: prFilter,
            callback: (v) {
              if (v != 'همه') return;
              prFilter.value = v;
              init();
            },
          ),
          const SizedBox(height: 10),
          const Text('فیلتر نوع، موجودی و قیمت فعلاً در دسترس نیست.'),
          MyTab(
            tab: const ['همه', 'فعال', 'پیش‌نویس', 'موجود', 'ناموجود', 'آرشیو'],
            enabledValues: statuses.keys.toSet(),
            value: typeFilter,
            callback: (v) {
              if (!statuses.containsKey(v)) return;
              typeFilter.value = v;
              filtered.value = true;
              init();
            },
          ),
          const SizedBox(height: 5),
          MyDivider(),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('بازه قیمت:'), Text('—')],
          ),
          Tooltip(
            message: 'فیلتر قیمت فعلاً در دسترس نیست.',
            child: RangeSlider(
              values: RangeValues(0, 1),
              min: 0,
              max: 1,
              onChanged: null,
            ),
          ),
          MyDivider(),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('دسته‌بندی:'),
                IconButton(
                  onPressed:
                      loading.value ||
                          !canFilterCategories ||
                          categories.isEmpty
                      ? null
                      : () {
                          CatInput(
                            controller: categoryController,
                            type: 'product',
                            categories: categories.toList(),
                            selected: filteredCatId
                                .where(
                                  (id) => categories.any((v) => v.id == id),
                                )
                                .toList(),
                            onChanged: (v) {},
                            name: 'name',
                          ).productCatSelct(context, (List v) {
                            filteredCat.value = [];
                            filteredCat.addAll(
                              v.map<Map<String, String>>(
                                (item) => {
                                  'uid': item['uid'] as String,
                                  'name': item['name'] as String,
                                },
                              ),
                            );
                            filteredCatId.value = [];
                            for (var i = 0; i < filteredCat.length; i++) {
                              filteredCatId.add(filteredCat[i]['uid']!);
                            }
                            filtered.value = true;
                            init();
                          }, notadd: false);
                        },
                  icon: const Icon(IconsaxPlusLinear.add),
                ),
              ],
            ),
          ),
          Obx(() {
            if (categoryError.value != null) {
              return Text('دسته‌بندی‌ها دریافت نشدند: ${categoryError.value}');
            }
            if (!canFilterCategories) {
              return const Text('اجازه مشاهده دسته‌بندی‌ها را ندارید.');
            }
            return const SizedBox.shrink();
          }),
          Obx(
            () => Wrap(
              children: [
                for (int i = 0; i < filteredCat.length; i++)
                  selectedCat(filteredCat[i]),
              ],
            ),
          ),
          MyDivider(),
          Obx(() {
            final busy = loading.value;
            final items = [
              const ItemValue(text: 'همه برندها', data: null),
              for (final brand in brands)
                ItemValue(
                  text:
                      '${brand.name}${brand.status == 'ARCHIVED' ? ' (آرشیو)' : ''}',
                  data: brand.id,
                ),
              if (brandId.value != null &&
                  !brands.any((v) => v.id == brandId.value))
                ItemValue(
                  text: 'برند انتخاب‌شده (شناسه: ${brandId.value})',
                  data: brandId.value,
                ),
            ];
            return Column(
              children: [
                Dropdown(
                  name: 'برند',
                  itemValue: true,
                  items_Value: items,
                  defaultValue: items
                      .where((v) => v.data == brandId.value)
                      .firstOrNull,
                  disable: busy || !canFilterBrands,
                  onChange: (value) {
                    if (!valid || loading.value || !canFilterBrands) return;
                    brandId.value = (value as ItemValue).data as String?;
                    init();
                  },
                ),
                if (brandError.value != null)
                  Text('برندها دریافت نشدند: ${brandError.value}')
                else if (!canFilterBrands)
                  const Text('اجازه مشاهده برندها را ندارید.'),
                if (brandError.value != null || categoryError.value != null)
                  BTN(
                    name: 'دریافت دوباره فهرست فیلترها',
                    icon: IconsaxPlusLinear.refresh,
                    onTap: init,
                    disabled: busy,
                  ),
              ],
            );
          }),
          const SizedBox(height: 30),
          Container(
            alignment: Alignment.bottomCenter,
            child: Obx(
              () => Row(
                children: [
                  Flexible(
                    child: BTN(
                      borderOnly: true,
                      color: darkMode.isFalse
                          ? AppColors.backgroundDarkMode
                          : AppColors.background,
                      icon: null,
                      onTap: () {
                        Get.back();
                      },
                      navigate: true,
                      name: 'بستن',
                    ),
                  ),
                  Flexible(
                    child: BTN(
                      //  type: BTNType.cancel,
                      color: darkMode.isFalse
                          ? AppColors.backgroundDarkMode
                          : AppColors.background,
                      borderOnly: true,
                      icon: IconsaxPlusLinear.close_square,
                      onTap: () {
                        resetFilters();
                        Get.back();
                      },
                      name: 'حذف همه فیلتر‌ها',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      title: 'فیلتر نمایش محصولات',
    );
    categoryController.dispose();
  }

  Widget selectedCat(Map<String, String> cat) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(
          color: darkMode.isTrue
              ? AppColors.background
              : AppColors.backgroundDarkMode,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cat['name'] ?? ''),
          const SizedBox(width: 20),
          InkWell(
            onTap: () {
              int i = filteredCat.indexOf(cat);
              filteredCat.removeAt(i);
              filteredCatId.removeAt(i);
              init();
            },
            child: Icon(
              IconsaxPlusLinear.close_square,
              color: darkMode.isTrue
                  ? AppColors.background.withValues(alpha: 0.6)
                  : AppColors.backgroundDarkMode.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
