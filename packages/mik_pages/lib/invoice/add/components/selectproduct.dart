import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_data/source/remote/models/pim_category.dart';
import 'package:mik_data/source/remote/models/pim_attribute.dart';
import 'package:mik_data/source/remote/models/pim_variant.dart';
import 'package:mik_components/elements/product_variant_options.dart';
// ignore_for_file: invalid_use_of_protected_member, prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/mobile.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/productImage.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

import 'model.dart';
part 'itemSelect.dart';

List<InvoiceItemModel> _selected = [];

class SelectProductForInvoice extends GetView {
  ///'preSell','sell','preInvoice','buy'
  late final String? type;

  ///'service','product'
  late final String productType;
  late final List<InvoiceItemModel> selected;
  late final String? warehouseUID;
  late final String? title;
  late final dynamic callback;
  final RxBool change = false.obs;
  late final String? branchUID;
  SelectProductForInvoice({
    required this.productType,
    required this.type,
    required this.selected,
    required this.callback,
    this.branchUID,
    this.title,
    this.warehouseUID,
    super.key,
  }) : remote = null;

  late final ({
    Widget search,
    Widget products,
    Widget footer,
    List<PimCategory> categories,
    String? selected,
    ValueChanged<String?> onCategory,
  })?
  remote;
  SelectProductForInvoice.remote({
    super.key,
    required Widget search,
    required Widget products,
    required Widget footer,
    required List<PimCategory> categories,
    required String? selectedCategory,
    required ValueChanged<String?> onCategory,
  }) {
    remote = (
      search: search,
      products: products,
      footer: footer,
      categories: categories,
      selected: selectedCategory,
      onCategory: onCategory,
    );
  }

  final search = TextEditingController();
  final RxList<ProductDB> pList = <ProductDB>[].obs;
  final RxList<CategoryDB> catList = <CategoryDB>[].obs;
  final RxString catSelected = ''.obs;

  @override
  Widget build(BuildContext context) {
    final catalog = remote;
    if (catalog != null) {
      return MainMobile(
        initState: () async => '',
        header: Header.page(context, text: 'افزودن به فاکتور'),
        child: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: catalog.search,
            ),
            if (catalog.categories.isNotEmpty)
              SizedBox(
                height: 30,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 10, left: 3),
                      child: Text('دسته‌بندی‌ها: '),
                    ),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final category in catalog.categories)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: InkWell(
                                onTap: () => catalog.onCategory(
                                  catalog.selected == category.id
                                      ? null
                                      : category.id,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: darkMode.isTrue
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    ),
                                    color: catalog.selected == category.id
                                        ? AppColors.primary
                                        : null,
                                  ),
                                  child: Text(
                                    category.name,
                                    style: TextStyle(
                                      color: catalog.selected == category.id
                                          ? Colors.white
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: catalog.products),
            catalog.footer,
          ],
        ),
      );
    }
    _selected = [];
    if (selected.isNotEmpty) {
      _selected.addAll(selected); // = selected; //.map((e) => {'uid': e.uid, 'prouid': e.pro.map((p) => p['uid']).toList()}).toList();
    }

    return MainMobile(
      initState: () async => init(''),
      header: Responsive.isMobile(context)
          ? Header.page(context, text: title ?? 'افزودن به فاکتور')
          : null,
      child: (d) => Column(
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 5),
            child: MySearchBar(
              type: SearchBarType.product,
              callback: (v) {
                if (v.toString().length > 2) {
                  catSelected.value = '';
                  pList.value = product.values
                      .where(
                        (p) =>
                            !(p.archive ?? false) &&
                            p.type == productType &&
                            con(p) &&
                            p.name!.toLowerCase().toEnglishDigit().contains(
                              v.toString().toLowerCase().toEnglishDigit(),
                            ),
                      )
                      .toList();
                } else {
                  pList.value = product.values
                      .where(
                        (p) =>
                            !(p.archive ?? false) &&
                            p.type == productType &&
                            con(p),
                      )
                      .toList();
                }
              },
            ),
          ),
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(right: 10, left: 3),
                  child: const Text('دسته‌بندی‌ها: '),
                ),
                Flexible(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: catList.length,
                    itemBuilder: (context, i) {
                      return Container(
                        margin: const EdgeInsets.only(
                          right: 5,
                          left: 5,
                          bottom: 5,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => init(catList[i].uid!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: darkMode.isTrue
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                              color: catSelected.value == catList[i].uid
                                  ? AppColors.primary
                                  : null,
                            ),
                            child: Text(
                              catList[i].name ?? '',
                              style: TextStyle(
                                color: catSelected.value == catList[i].uid
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pList.isNotEmpty
                ? ListView.builder(
                    itemCount: pList.length,
                    itemBuilder: (context, index) {
                      List<InvoiceItemModel> its = _selected
                          .where((e) => e.uid == pList[index].uid)
                          .toList();
                      return ProductItemSelect(
                        item: pList[index],
                        itemSelect: its.isNotEmpty ? its[0] : null,
                        warehouseUID: warehouseUID,
                        branchUID: branchUID,
                        type: type!,
                        callback: (v) => changeSelect(v),
                      );
                    },
                  )
                : EmptyList(
                    text: 'هیچ محصولی در این انبار موجودی ندارد!',
                    icon: IconsaxPlusLinear.box_remove,
                  ),
          ),
          BTN(
            onTap: () {
              callback(_selected);
              Get.back();
            },
            name: 'تایید انتخاب شده‌ها',
            type: BTNType.ok,
          ),
        ],
      ),
    );
  }

  void changeSelect(Map<String, dynamic> e) {
    bool pExist = false;
    bool exist = false;
    int index = -1;
    for (var i = 0; i < _selected.length; i++) {
      if (_selected[i].uid == e['uid']) {
        pExist = true;
        index = i;
        if (_selected[i].pro.indexWhere((p) => p.uid == e['prouid']) > -1) {
          exist = true;
          //_selected[i]['prouid'].remove(e['prouid']);
          _selected[i].pro.removeWhere((p) => p.uid == e['prouid']);
          if (_selected[i].pro.isEmpty) {
            _selected.removeAt(i);
          }
          break;
        }
      }
    }
    if (pExist && !exist) {
      _selected[index].pro.add(
        InvoiceProItemModel(
          uid: e['prouid'],
          amount: e['amount'] ?? 1.0,
          price: type == 'buy' ? 0 : e['price'] ?? 0,
          buyPrice: type == 'buy' ? 0 : e['buyPrice'] ?? 0,
          warehouseUID: e['warehouseUID'] ?? warehouseUID,
          parameters: [],
        ),
      );
    }
    if (!pExist) {
      _selected.add(
        InvoiceItemModel(
          uid: e['uid'],
          id: 0,
          name: e['name'],
          barcode: e['barcode'] ?? '',
          type: productType,
          pro: [
            InvoiceProItemModel(
              uid: e['prouid'],
              amount: e['amount'] ?? 1.0,
              price: type == 'buy' ? 0 : e['price'] ?? 0,
              buyPrice: type == 'buy' ? 0 : e['buyPrice'] ?? 0,
              warehouseUID: e['warehouseUID'] ?? warehouseUID,
              parameters: [],
            ),
          ],
        ),
      );
    }
    // exist
    //     ? _selected.removeWhere(
    //         (w) => w['uid'] == e['uid'] && w['prouid'] == e['prouid'])
    //     : _selected.add(Map<String, String>.from(e));
  }

  bool con(ProductDB it) {
    if (type == 'sell' || type == 'w2w') {
      if (warehouseUID != null && warehouseUID != '') {
        return ProductFX.productInWarehouse(it.uid!, '-', warehouseUID!) > 0;
      }
      if (branchUID != null && branchUID != '') {
        return ProductFX.productInBranch(it.uid!, '-', branchUID!) > 0;
      }
      return true;
      // return it.inventory > 0;
    }
    return true;
  }

  String init(String catUID) {
    List pw = [];
    if (warehouseUID != null) {
      pw = warehouse.values
          .where((w) => w.wuid == warehouseUID && w.inventory > 0)
          .toList()
          .map((e) => e.puid)
          .toList();
    }
    if (branchUID != null && branchUID != '') {
      pw.addAll(
        branchAccess.values
            .where((t) => t.branchUID == branchUID)
            .toList()
            .map((p) => p.warehouseUID)
            .toList(),
      );
    }
    if (pw.isEmpty) {
      pw = warehouse.values
          .where((w) => w.inventory > 0)
          .toList()
          .map((e) => e.puid)
          .toList();
    }
    search.clear();
    catList.value = category.values
        .where(
          (p) =>
              p.type == productType ||
              (p.type == null && productType == 'product'),
        )
        .toList();
    catList.value = [
      CategoryDB(
        id: 0,
        uid: '',
        name: 'همه',
        parent: '',
        inserter: mikyarProfileID,
      ),
      ...catList.value,
    ];
    catSelected.value = catUID;
    if (catUID == '') {
      if (warehouseUID != null) {
        pList.value = product.values
            .where(
              (e) =>
                  !(e.archive ?? false) &&
                  e.type == productType &&
                  pw.contains(e.uid) &&
                  con(e),
            )
            .toList();
      } else {
        pList.value = product.values
            .where(
              (e) => !(e.archive ?? false) && e.type == productType && con(e),
            )
            .toList();
      }
    } else {
      if (warehouseUID != null) {
        pList.value = product.values
            .where(
              (element) =>
                  !(element.archive ?? false) &&
                  element.type == productType &&
                  con(element) &&
                  element.catIDList != null &&
                  !(element.archive ?? false) &&
                  element.catIDList!.contains(catUID) &&
                  pw.contains(element.uid),
            )
            .toList();
      } else {
        pList.value = product.values
            .where(
              (element) =>
                  !(element.archive ?? false) &&
                  element.type == productType &&
                  con(element) &&
                  element.catIDList != null &&
                  !(element.archive ?? false) &&
                  element.catIDList!.contains(catUID),
            )
            .toList();
      }
    }
    pList.value = pList.value.reversed.toList();
    change.toggle();
    return '';
  }
}

Widget buildSelectProductForInvoiceRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return SelectProductForInvoice(
    productType: args.required<String>('productType'),
    type: args.required<String>('type'),
    selected: args.required<List<InvoiceItemModel>>('selected'),
    callback: args.required<dynamic>('callback'),
    branchUID: args.optional<String>('branchUID'),
    title: args.optional<String>('title'),
    warehouseUID: args.optional<String>('warehouseUID'),
  );
}
