import 'package:mik_router/mik_router.dart' as nav_routes;
// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_consts/units.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/readWriteFile.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/invoice/add/components/model.dart';
import 'package:mik_pages/chatBase/addProduct/common/additionalPrice.dart';
import 'package:mik_pages/chatBase/addProduct/common/detailsModel.dart';
import 'package:mik_pages/chatBase/addProduct/common/featureSheet.dart';
import 'package:mik_pages/chatBase/addProduct/common/productProperty.dart';

class AddGroupDetailsController extends GetxController {
  final List<String> productNames;
  ProductDB? productForEdit;
  bool firstTime;
  late final List<ProductDetailsModel> products;
  late final RxList<bool> productCompletionStatus;

  AddGroupDetailsController(this.productNames, this.productForEdit, {this.firstTime = false});

  final PageController pageController = PageController();
  final RxInt currentPage = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (productForEdit != null) {
      //edit product
      final model = ProductDetailsModel(name: productForEdit!.name!, draftUid: productForEdit!.uid);
      List<String> img = [];
      for (var i = 0; i < productForEdit!.img!.length; i++) {
        img.add('${prImageDir!.path}/${productForEdit!.id}/${productForEdit!.img?[i]}');
      }
      model.image.value = img;
      model.nameController.text = productForEdit!.name!;
      model.productUID = productForEdit!.uid;
      model.productID = productForEdit!.id;
      model.productType.value = productForEdit!.type == 'product' ? 'کالا' : 'خدمت';
      // model.selectedUnit
      model.categoryUID = productForEdit!.catIDList ?? [];
      model.categoryController.text = ProductFX.catListName(productForEdit!.catIDList!);
      model.unitId = productForEdit!.unitCode ?? 0;
      model.unitController.text = ProductFX.unitName(productForEdit!.unitCode);
      model.taxIDController.text = productForEdit!.taxID ?? '';
      model.taxController.text = ((productForEdit!.vat ?? 0) == 0 ? '' : productForEdit!.vat).toString();
      model.commissionAmountController.text = ((productForEdit!.commission ?? 0) == 0 ? '' : productForEdit!.commission).toString();
      model.isCommissionFixed.value = productForEdit!.isCommissionFixed ?? true;
      model.barcodeController.text = productForEdit!.barcode ?? '';
      products = [model];
    } else {
      products = productNames.map((name) {
        final model = ProductDetailsModel(name: name);
        // پیدا کردن draft مربوطه از دیتابیس
        bool draftFound = false;
        for (var draft in productDraft.values) {
          if (draft.name == name) {
            model.draftUid = draft.uid;
            _loadFromDraft(model, draft);
            draftFound = true;
            break;
          }
        }

        // اگر draft وجود نداشت، یک draft جدید ایجاد کن
        if (!draftFound && (!(productNames.length == 1 && productNames[0] == ''))) {
          final newDraftUid = ID.uidNew();
          model.draftUid = newDraftUid;
          final newDraft = ProductDraftDB(uid: newDraftUid, name: name, createdDate: DateTime.now().toString());
          productDraft.add(newDraft);
        }

        return model;
      }).toList();
      if (product.isEmpty && invoice.isEmpty) {
        firstTime = true;
      }
      productCompletionStatus = List.filled(products.length, false).obs;
    }
    fetchProperties();
  }

  void fetchProperties() {
    // Assuming productProperty is a global Hive box or list available from variable.dart
    // If not, I might need to find where it is defined. Based on previous context, it seems to be in variable.dart
    // Checking imports... 'package:mik/data/utils/variable.dart' is imported.
    try {
      if (productProperty.isNotEmpty) {
        for (var product in products) {
          product.availableProperties.assignAll(productProperty.values.toList());
        }
      }
    } catch (e) {}
  }

  void nextPage() {
    // Validation for the current product
    final currentProduct = products[currentPage.value];
    if (currentProduct.productType.value == '') {
      Alert.warning('لطفا نوع محصول را انتخاب کنید.');
      return;
    }
    // Always required validations
    if (currentProduct.categoryUID.isEmpty) {
      Alert.warning('لطفا دسته بندی را انتخاب کنید.');
      return;
    }
    if (currentProduct.sellPriceController.text.isEmpty) {
      Alert.warning('لطفا قیمت فروش را وارد کنید.');
      return;
    }

    // Conditional validations based on firstTime
    if (firstTime) {
      if (currentProduct.productType.value == 'کالا' && currentProduct.buyPriceController.text.isEmpty) {
        Alert.warning('لطفا قیمت خرید را وارد کنید.');
        return;
      }
      if (currentProduct.productType.value == 'کالا' && currentProduct.stockController.text.isEmpty && currentProduct.variantStocks.isEmpty) {
        Alert.warning('لطفا موجودی را وارد کنید.');
        return;
      }
    }

    // Validate variant stocks if they exist
    if (currentProduct.variantStocks.isNotEmpty) {
      int totalVariantStock = 0;
      currentProduct.variantStocks.forEach((key, value) {
        totalVariantStock += int.tryParse(value) ?? 0;
      });
      if (currentProduct.stockController.text.isNotEmpty) {
        int totalStock = int.tryParse(currentProduct.stockController.text) ?? 0;
        if (totalVariantStock != totalStock) {
          Alert.warning('مجموع موجودی تنوع‌ها باید دقیقا برابر با موجودی کل ($totalStock) باشد. مجموع فعلی: $totalVariantStock');
          return;
        }
      }
    }

    // ذخیره در draft قبل از رفتن به صفحه بعد
    _saveToDraft(currentProduct);

    // Mark current product as complete
    productCompletionStatus[currentPage.value] = true;

    if (currentPage.value < products.length - 1) {
      pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      // Navigate to summary screen
      currentPage.value = products.length; // Set to summary page index
    }
  }

  void previousPage() {
    // ذخیره محصول فعلی قبل از رفتن به عقب
    if (currentPage.value < products.length) {
      _saveToDraft(products[currentPage.value]);
    }

    if (currentPage.value > 0) {
      pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  void skipCurrentProduct() {
    // Mark as incomplete (false)
    productCompletionStatus[currentPage.value] = false;

    if (currentPage.value < products.length - 1) {
      pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      // Navigate to summary screen
      currentPage.value = products.length; // Set to summary page index
    }
  }

  void goToProduct(int index) {
    // First change currentPage to trigger the view switch
    currentPage.value = index;
    // Then after the widget rebuilds, jump to the correct page
    // Using scheduleMicrotask ensures this happens after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.jumpToPage(index);
      }
    });
  }

  removeProduct(int index) async {
    var p = products[index];

    Confirm.con(
      Get.context,
      onTapConfirm: () async {
        for (var i = 0; i < productDraft.length; i++) {
          if (productDraft.getAt(i)!.uid == p.draftUid) {
            await productDraft.deleteAt(i);
          }
        }
        products.removeAt(index);
        productCompletionStatus.removeAt(index);
        Get.back();
        if (products.isEmpty) {
          Get.back();
        }
        Alert.success('محصول با موفقیت حذف شد.');
      },
      confirmText: 'حذف محصول ${p.name}',
      type: ConfirmType.DELETE,
    );
  }

  Future<void> editProduct() async {
    List<String> img = [];
    for (int i = 0; i < products[0].image.length; i++) {
      img.add(products[0].image[i].toString().split('/').last);
    }
    final productDB = ProductDB(
      uid: productForEdit!.uid,
      taxID: products[0].taxIDController.text,
      id: productForEdit!.id,
      name: products[0].name,
      img: img,
      categoryID: 0,
      catIDList: products[0].categoryUID.toList(),
      barcode: products[0].barcodeController.text,
      commission: double.tryParse(products[0].commissionAmountController.text),
      isCommissionFixed: products[0].isCommissionFixed.value,
      date: productForEdit!.date,
      archive: productForEdit!.archive ?? false,
      type: productForEdit!.type, //products[0].productType.value == 'کالا' ? 'product' : 'service', // 'کالا' or 'خدمات'
      backup: 'edit',
      vat: double.tryParse(products[0].taxController.text) ?? 0.0,
      unitCode: products[0].unitId,
      inserter: 0,
    );

    for (var i = 0; i < product.length; i++) {
      if (product.getAt(i)!.uid == productForEdit!.uid) {
        await SaveHelper.save(productDB, index: i);
        break;
      }
    }

    // Save images to disk
    if (products[0].image.isNotEmpty) {
      try {
        await RW.edit(type: RWType.product, dir: products[0].productID, newPath: products[0].image.value);
      } catch (e) {
        Future.delayed(Duration(milliseconds: 800), () {
          Alert.warning('ذخیره تصاویر با خطا مواجه شد.');
        });
      }
    }

    Get.back();
    Alert.success('ویرایش محصول انجام شد.');

    // حذف تمام drafts بعد از ثبت موفق
    await _clearAllDrafts();
  }

  Future<void> saveProducts() async {
    String uuid = ID.uidNew();
    List<InvoiceItemModel> invoiceItems = [];
    String warehouseUID = '';
    if (firstTime && warehouseName.isNotEmpty) {
      warehouseUID = warehouseName.getAt(0)!.uid!;
    }

    for (var i = 0; i < products.length; i++) {
      var productModel = products[i];
      List<String> img = [];
      for (int i = 0; i < productModel.image.length; i++) {
        img.add(productModel.image[i].toString().split('/').last);
      }
      productModel.productUID = ID.uidNew();
      productModel.productID = ID.newId(product);
      final productDB = ProductDB(
        uid: productModel.productUID,
        taxID: productModel.taxIDController.text,
        id: productModel.productID,
        name: productModel.name,
        img: img,
        categoryID: 0,
        catIDList: productModel.categoryUID.toList(),
        barcode: productModel.barcodeController.text,
        commission: double.tryParse(productModel.commissionAmountController.text),
        isCommissionFixed: productModel.isCommissionFixed.value,
        date: DateTime.now().toString(),
        archive: false,
        type: productModel.productType.value == 'کالا' ? 'product' : 'service', // 'کالا' or 'خدمات'
        backup: 'new',
        vat: double.tryParse(productModel.taxController.text) ?? 0.0,
        unitCode: productModel.unitId,
        inserter: 0,
      );

      // Prepare image list - extract filenames only
      List imgOrderList = [];
      for (var element in productModel.image) {
        imgOrderList.add(element.toString().split('/').last);
      }
      productDB.img = imgOrderList;

      await SaveHelper.save(productDB);

      // Save images to disk
      if (productModel.image.isNotEmpty) {
        await RW.save(type: RWType.product, dir: productModel.productID, filePath: productModel.image.value);
      }
      List<ProductPropertyDB> selectedProperties = [];
      for (var properties in productModel.properties) {
        ProductPropertyDB? p;
        if (properties.uid != null) {
          try {
            p = productProperty.values.firstWhere((element) => element.uid == properties.uid);
          } catch (e) {}
        }
        if (p == null) {
          try {
            p = productProperty.values.firstWhere((element) => element.name == properties.name);
          } catch (e) {}
        }

        if (p != null) {
          ProductPropertyDB tempP = ProductPropertyDB(uid: p.uid, name: p.name, value: properties.valuesWithId, type: p.type, inserter: p.inserter, backup: p.backup);
          selectedProperties.add(tempP);
        }
      }

      // Map to store custom prices for variants: {VariantUID: {PriceName: PriceValue}}
      Map<String, Map<String, int>> variantCustomPrices = {};
      List<InvoiceProItemModel> proItems = [];
      int buyPrice = Price.toInt(productModel.buyPriceController.text);

      if (selectedProperties.isNotEmpty) {
        var combinations = _generateCombinations(selectedProperties);
        for (var combination in combinations) {
          String variantUID = ID.uidNew();
          ProductProDB p = ProductProDB(uid: variantUID, productUID: productModel.productUID, property: combination, desc: '', backup: 'new', inserter: 0);
          await SaveHelper.save(p);

          // Check for custom prices for this variant
          String variantKey = productModel.getVariantKey(combination);
          if (productModel.variantPrices.containsKey(variantKey)) {
            variantCustomPrices[variantUID] = productModel.variantPrices[variantKey]!;
          }

          if (firstTime) {
            // Get stock from variantStocks map
            final stock = double.tryParse((productModel.variantStocks[variantKey] ?? '0').toString()) ?? 0;
            // Get custom buy price if available
            int variantBuyPrice = buyPrice;
            if (productModel.variantPrices.containsKey(variantKey) && productModel.variantPrices[variantKey]!.containsKey('buyPrice')) {
              variantBuyPrice = productModel.variantPrices[variantKey]!['buyPrice']!;
            }

            if (stock > 0) {
              proItems.add(InvoiceProItemModel(uid: variantUID, amount: stock, price: variantBuyPrice, buyPrice: variantBuyPrice, warehouseUID: warehouseUID, parameters: []));
            }
          }
        }
      } else if (firstTime) {
        // Simple product
        double stock = double.tryParse(productModel.stockController.text) ?? 0;
        if (stock > 0) {
          proItems.add(InvoiceProItemModel(uid: '-', amount: stock, price: buyPrice, buyPrice: buyPrice, warehouseUID: warehouseUID, parameters: []));
        }
      }

      if (firstTime && proItems.isNotEmpty) {
        invoiceItems.add(
          InvoiceItemModel(
            id: productModel.productID!,
            uid: productModel.productUID!,
            pro: proItems,
            name: productModel.name,
            barcode: productModel.barcodeController.text,
            type: productModel.productType.value == 'کالا' ? 'product' : 'service',
          ),
        );
      }

      //save main Price
      String mainPriceUID = ID.uidNew();
      Map<String, int> mainPricePro = {};
      variantCustomPrices.forEach((variantUID, prices) {
        if (prices.containsKey('main')) {
          mainPricePro[variantUID] = prices['main']!;
        }
      });

      ProductPriceDB p = ProductPriceDB(
        uid: mainPriceUID,
        puid: productModel.productUID,
        pro: mainPricePro.isNotEmpty ? mainPricePro : {},
        price: Price.toInt(productModel.sellPrice.value),
        name: 'پایه',
        defaultPrice: true,
        inserter: 0,
        backup: 'new',
      );
      await SaveHelper.save(p);

      for (var i = 0; i < productModel.additionalPrices.length; i++) {
        var prices = productModel.additionalPrices[i];

        prices.uid = ID.uidNew();
        Map<String, int> additionalPricePro = {};
        variantCustomPrices.forEach((variantUID, customPrices) {
          if (customPrices.containsKey(prices.nameController.text)) {
            additionalPricePro[variantUID] = customPrices[prices.nameController.text]!;
          }
        });

        ProductPriceDB p = ProductPriceDB(
          uid: prices.uid,
          puid: productModel.productUID,
          pro: additionalPricePro.isNotEmpty ? additionalPricePro : {},
          price: Price.toInt(prices.priceController.text),
          name: prices.nameController.text,
          defaultPrice: false,
          inserter: 0,
          backup: 'new',
        );
        await SaveHelper.save(p);
      }
      await Future.delayed(Duration(milliseconds: 70));
    }

    if (firstTime && invoiceItems.isNotEmpty) {
      //save first Invoice

      double totalPrice = 0;

      for (var i = 0; i < invoiceItems.length; i++) {
        var item = invoiceItems[i];

        for (var j = 0; j < item.pro.length; j++) {
          var pro = item.pro[j];

          totalPrice += pro.amount * pro.price;
        }
      }

      await InvoiceFX.addNew(
        date: DateTime.now().toIso8601String(),
        personID: 0,
        personUID: '-',
        type: 'buy',
        cash: 'paid',
        notPaid: 0,
        otherPay: 0,
        allBill: [],
        tPrice: totalPrice.toInt(),
        paidPrice: totalPrice.toInt(),
        chequeList: [],
        items: invoiceItems,
        excess: 0,
        discount: 0,
        shippingCost: 0,
        status: null,
        commission: 0,
        cRecipient: 0,
        cRecipientUID: '',
        cStatus: 0,
        branchUID: '',
        first: true,
      );
      await Future.delayed(Duration(seconds: 2));
      await _clearAllDrafts();
      final box = await Hive.openBox<OnboardingDraftDB>('onboardingDraft');
      final draft = OnboardingDraftDB(
        uid: 'draft_001', // Single draft for now
        createdDate: DateTime.now().toIso8601String(),
        currentStage: 'debts', //currentStage.value.toString().split('.').last,
      );
      await box.put('draft_001', draft);

      Get.offNamed(
        nav_routes.RoutesName.LEGACY_ONBOARDING_STEP2,
        preventDuplicates: false,
      );
      // App-specific onboarding cards are not owned by this shared page.
    }
    Get.back();
    if (products.length == 1) {
      Alert.success('محصول ثبت شد.');
    } else {
      Alert.success('تمام محصولات ثبت شدند.');
    }
    // حذف تمام drafts بعد از ثبت موفق
    await _clearAllDrafts();
  }

  Future<void> _clearAllDrafts() async {
    try {
      await productDraft.clear();
    } catch (e) {}
  }

  void _loadFromDraft(ProductDetailsModel model, ProductDraftDB draft) {
    // بارگذاری فیلدهای ساده
    if (draft.productType != null && draft.productType!.isNotEmpty) {
      model.productType.value = draft.productType!;
    }
    if (draft.sellPrice != null && draft.sellPrice!.isNotEmpty) {
      model.sellPriceController.text = draft.sellPrice!;
      model.sellPrice.value = draft.sellPrice!;
    }
    if (draft.buyPrice != null && draft.buyPrice!.isNotEmpty) {
      model.buyPriceController.text = draft.buyPrice!;
    }
    if (draft.stock != null && draft.stock!.isNotEmpty) {
      model.stockController.text = draft.stock!;
    }
    if (draft.categoryUID != null && draft.categoryUID!.isNotEmpty) {
      model.categoryUID = List<String>.from(draft.categoryUID!);
      List<CategoryDB> cat = category.values.where((e) => model.categoryUID.contains(e.uid)).toList();
      String catString = '';
      for (var element in cat) {
        catString += catString == '' ? element.name! : ', ${element.name!}';
      }

      model.categoryController.text = catString;
    }
    if (draft.unitId != null) {
      model.unitId = draft.unitId;
      model.unitController.text = productUnits[draft.unitId!]['name'].toString();
    }
    if (draft.tax != null && draft.tax!.isNotEmpty) {
      model.taxController.text = draft.tax!;
    }
    if (draft.commissionAmount != null && draft.commissionAmount!.isNotEmpty) {
      model.commissionAmountController.text = draft.commissionAmount!;
    }
    if (draft.isCommissionFixed != null) {
      model.isCommissionFixed.value = draft.isCommissionFixed!;
    }
    if (draft.barcode != null && draft.barcode!.isNotEmpty) {
      model.barcodeController.text = draft.barcode!;
    }
    if (draft.image != null && draft.image!.isNotEmpty) {
      model.image.value = List.from(draft.image!);
    }

    // بارگذاری فیلدهای پیچیده از JSON
    try {
      if (draft.additionalPricesJson != null && draft.additionalPricesJson!.isNotEmpty) {
        final pricesData = jsonDecode(draft.additionalPricesJson!) as List;
        model.additionalPrices.clear();
        for (var priceData in pricesData) {
          final price = AdditionalPrice(
            nameController: TextEditingController(text: priceData['name'] ?? ''),
            priceController: TextEditingController(text: priceData['price'] ?? ''),
            uid: priceData['uid'],
          );
          model.additionalPrices.add(price);
        }
      }

      if (draft.propertiesJson != null && draft.propertiesJson!.isNotEmpty) {
        final propertiesData = jsonDecode(draft.propertiesJson!) as List;
        model.properties.clear();
        for (var propData in propertiesData) {
          final property = ProductProperty();
          property.name = propData['name'] ?? '';
          property.uid = propData['uid'];
          property.values.value = List<String>.from(propData['values'] ?? []);
          property.valuesWithId.value = List<Map<String, dynamic>>.from(propData['valuesWithId'] ?? []);
          model.properties.add(property);
        }
      }

      if (draft.variantsJson != null && draft.variantsJson!.isNotEmpty) {
        final variantStocksData = jsonDecode(draft.variantsJson!) as Map<String, dynamic>;
        model.variantStocks.clear();
        variantStocksData.forEach((key, value) {
          model.variantStocks[key] = value.toString();
        });
      }

      if (draft.variantPricesJson != null && draft.variantPricesJson!.isNotEmpty) {
        final variantPricesData = jsonDecode(draft.variantPricesJson!) as Map<String, dynamic>;
        model.variantPrices.clear();
        variantPricesData.forEach((key, value) {
          model.variantPrices[key] = Map<String, int>.from(value);
        });
      }
    } catch (e) {}
  }

  Future<void> _saveToDraft(ProductDetailsModel product) async {
    if (product.draftUid == null) return;

    // پیدا کردن index در database
    int index = -1;
    for (var i = 0; i < productDraft.length; i++) {
      if (productDraft.getAt(i)?.uid == product.draftUid) {
        index = i;
        break;
      }
    }

    if (index >= 0) {
      final draft = productDraft.getAt(index)!;

      // به‌روزرسانی فیلدها
      draft.productType = product.productType.value.isNotEmpty ? product.productType.value : null;
      draft.sellPrice = product.sellPrice.value.isNotEmpty ? product.sellPrice.value : null;
      draft.buyPrice = product.buyPriceController.text.isNotEmpty ? product.buyPriceController.text : null;
      draft.stock = product.stockController.text.isNotEmpty ? product.stockController.text : null;
      draft.categoryUID = product.categoryUID.isNotEmpty ? product.categoryUID.toList() : null;
      draft.unitId = product.unitId;
      draft.tax = product.taxController.text.isNotEmpty ? product.taxController.text : null;
      draft.commissionAmount = product.commissionAmountController.text.isNotEmpty ? product.commissionAmountController.text : null;
      draft.isCommissionFixed = product.isCommissionFixed.value;
      draft.barcode = product.barcodeController.text.isNotEmpty ? product.barcodeController.text : null;
      draft.image = product.image.isNotEmpty ? product.image.toList() : null;

      // سریالیزه کردن فیلدهای پیچیده به JSON
      try {
        // additionalPrices
        if (product.additionalPrices.isNotEmpty) {
          final pricesData = product.additionalPrices.map((price) => {'name': price.nameController.text, 'price': price.priceController.text, 'uid': price.uid}).toList();
          draft.additionalPricesJson = jsonEncode(pricesData);
        } else {
          draft.additionalPricesJson = null;
        }

        // properties
        if (product.properties.isNotEmpty) {
          final propertiesData = product.properties
              .map((property) => {'name': property.name, 'uid': property.uid, 'values': property.values.toList(), 'valuesWithId': property.valuesWithId.value})
              .toList();
          draft.propertiesJson = jsonEncode(propertiesData);
        } else {
          draft.propertiesJson = null;
        }

        // variantStocks
        if (product.variantStocks.isNotEmpty) {
          draft.variantsJson = jsonEncode(product.variantStocks);
        } else {
          draft.variantsJson = null;
        }
      } catch (e) {}

      // variantPrices
      if (product.variantPrices.isNotEmpty) {
        draft.variantPricesJson = jsonEncode(product.variantPrices);
      } else {
        draft.variantPricesJson = null;
      }

      await productDraft.putAt(index, draft);
    }
  }

  List<List<Map<String, dynamic>>> _generateCombinations(List<ProductPropertyDB> properties) {
    List<List<Map<String, dynamic>>> result = [[]];

    for (var property in properties) {
      List<List<Map<String, dynamic>>> nextResult = [];
      for (var existingCombination in result) {
        for (var value in property.value) {
          List<Map<String, dynamic>> newCombination = List.from(existingCombination);
          newCombination.add({'uid': property.uid, 'vid': value['id']});
          nextResult.add(newCombination);
        }
      }
      result = nextResult;
    }
    return result;
  }

  // void addAdditionalPrice(ProductDetailsModel product) {
  //   product.additionalPrices.add(AdditionalPrice());
  // }

  void removeAdditionalPrice(ProductDetailsModel product, int index) {
    product.additionalPrices[index].nameController.dispose();
    product.additionalPrices[index].priceController.dispose();
    product.additionalPrices.removeAt(index);
  }

  void editAdditionalPrice(BuildContext context, ProductDetailsModel product, int index) {
    final price = product.additionalPrices[index];
    final nameController = TextEditingController(text: price.nameController.text);
    final priceController = TextEditingController(text: price.priceController.text);
    final priceF = FocusNode();
    priceF.requestFocus();
    MyBottomSheet.view(
      context,
      title: 'ویرایش قیمت ${price.nameController.text}',
      child: (scrollController) => Column(
        children: [
          PriceInput(name: 'قیمت', focusNode: priceF, controller: priceController, require: true),
          Input(name: 'نام قیمت', controller: nameController, require: true),
          const SizedBox(height: 5),
          BTN(
            name: 'ذخیره',
            onTap: () {
              if (nameController.text.isEmpty) {
                Alert.error('لطفا نام قیمت را وارد کنید.');
                return;
              }
              if (priceController.text.isEmpty) {
                Alert.error('لطفا مبلغ را وارد کنید.');
                return;
              }

              price.nameController.text = nameController.text;
              price.priceController.text = priceController.text;
              _saveToDraft(product);
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  void addFeature(ProductDetailsModel product) {
    product.properties.add(ProductProperty());
  }

  void removeFeature(ProductDetailsModel product, int index) {
    product.properties[index].name;
    product.properties[index].valueInputController.dispose();
    product.properties.removeAt(index);
    generateVariants(product);
  }

  void addFeatureValue(ProductProperty feature, String value) async {
    if (value.isEmpty) return;

    // بررسی تکراری نبودن
    if (feature.valuesWithId.any((v) => v['name'] == value)) return;

    try {
      // پیدا کردن property مربوطه از دیتابیس
      ProductPropertyDB? property;
      if (feature.uid != null) {
        try {
          property = productProperty.values.firstWhere(
            (p) => p.uid == feature.uid,
            orElse: () => ProductPropertyDB(uid: '', name: '', value: [], inserter: 0),
          );
          if (property.uid.isEmpty) property = null;
        } catch (e) {
          property = null;
        }
      }

      if (property != null) {
        // بررسی وجود مقدار در دیتابیس
        final existsInDb = property.value.any((v) => v['name'] == value);

        Map<String, dynamic> newValue;
        if (existsInDb) {
          // مقدار در دیتابیس وجود دارد، استفاده از آن
          newValue = property.value.firstWhere((v) => v['name'] == value);
        } else {
          // مقدار جدید است، افزودن به دیتابیس
          newValue = {'name': value, 'code': '', 'id': (property.value.length + 1).toString()};
          property.value.add(newValue);

          // ذخیره در دیتابیس
          int index = productProperty.values.toList().indexWhere((element) => element.uid == property!.uid);
          if (index >= 0) {
            await SaveHelper.save(property, index: index);
          }
        }

        // افزودن به valuesWithId
        feature.valuesWithId.add(newValue);
      } else {
        // ویژگی جدید (بدون uid) - فقط در مدل محلی
        final newValue = {'name': value, 'code': '', 'id': (feature.valuesWithId.length + 1).toString()};
        feature.valuesWithId.add(newValue);
      }

      feature.valueInputController.clear();
    } catch (e) {}
  }

  void removeFeatureValue(ProductProperty feature, Map value) {
    feature.valuesWithId.remove(value);
  }

  void generateVariants(ProductDetailsModel product) {
    // product.variantStocks.clear(); // Clear existing variant stocks
    if (product.properties.isEmpty || product.properties.any((f) => f.valuesWithId.isEmpty)) {
      return;
    }

    // Generate all combinations of properties with their IDs
    // List<List<Map>> combinations = _getVariantCombinations(product);
    // Generate all combinations of properties with their IDs
    List<List<Map>> combinations = getVariantCombinations(product);

    for (var combination in combinations) {
      final key = product.getVariantKey(combination);
      // Initialize stock for new variants if not already present
      if (!product.variantStocks.containsKey(key)) {
        product.variantStocks[key] = '0';
      }
    }
  }

  List<List<Map>> getVariantCombinations(ProductDetailsModel product) {
    if (product.properties.isEmpty) {
      return [];
    }

    // Get all value sets with their IDs
    List<List<Map>> valueSets = product.properties.map((property) {
      return property.valuesWithId.map((valueMap) {
        return {'uid': property.uid, 'vid': valueMap['id'], 'name': valueMap['name']};
      }).toList();
    }).toList();

    // Generate all combinations
    List<List<Map>> combinations = [[]];
    for (var valueSet in valueSets) {
      List<List<Map>> newCombinations = [];
      for (var value in valueSet) {
        for (var combination in combinations) {
          newCombinations.add([...combination, value]);
        }
      }
      combinations = newCombinations;
    }

    return combinations;
  }

  void showAddFeatureSheet(BuildContext context, ProductDetailsModel product) {
    MyBottomSheet.view(
      context,
      child: (scrollController) => AddFeatureSheet(product: product, controller: this, scrollController: scrollController),
      title: 'افزودن ویژگی',
    );
  }

  void addExistingFeature(ProductDetailsModel product, ProductPropertyDB property, {List<Map<String, dynamic>>? selectedValues}) {
    // Check if feature already exists
    if (product.properties.any((f) => f.name == property.name)) {
      Alert.warning('این ویژگی قبلا اضافه شده است.');
      return;
    }

    final feature = ProductProperty();
    feature.name = property.name;
    feature.uid = property.uid;

    // اگر مقادیر انتخاب شده ارسال شده، فقط آنها را اضافه کن
    if (selectedValues != null && selectedValues.isNotEmpty) {
      for (var val in selectedValues) {
        feature.valuesWithId.add(val);
      }
    }
    // اگر نه، همه مقادیر را اضافه کن (رفتار قدیمی - برای سازگاری)
    else {
      for (var val in property.value) {
        feature.valuesWithId.add(val);
      }
    }

    product.properties.add(feature);
    generateVariants(product);
    FocusManager.instance.primaryFocus?.unfocus();
    // Get.back() حذف شد - فراخوانی‌کننده مسئول بستن است
  }

  @override
  void onClose() {
    for (var product in products) {
      product.buyPriceController.dispose();
      product.sellPriceController.dispose();
      product.sellPrice.value = '';
      product.stockController.dispose();
      product.categoryController.dispose();
      product.unitController.dispose();
      product.taxController.dispose();
      product.commissionAmountController.dispose();
      product.barcodeController.dispose();
      for (var price in product.additionalPrices) {
        price.nameController.dispose();
        price.priceController.dispose();
      }
      for (var feature in product.properties) {
        // feature.name.dispose(); // String doesn't need dispose
        feature.valueInputController.dispose();
      }
      // No need to dispose variant controllers as they are not stored persistently in the model anymore
    }
    pageController.dispose();
    super.onClose();
  }
}
