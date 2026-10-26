import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_pages/chatBase/addProduct/common/additionalPrice.dart';
import 'package:mik_pages/chatBase/addProduct/common/productProperty.dart';

class ProductDetailsModel {
  String name;
  String? draftUid; // UID از draft database برای به‌روزرسانی‌ها

  String? productUID;
  int? productID;
  final TextEditingController nameController = TextEditingController();

  RxList<dynamic> image = RxList();
  final TextEditingController buyPriceController = TextEditingController();
  final TextEditingController sellPriceController = TextEditingController();
  final RxString sellPrice = ''.obs;
  final TextEditingController stockController = TextEditingController();
  //List? category;
  List<String> categoryUID = <String>[];
  // RxList<ProductPriceDB> priceList = RxList();
  final TextEditingController categoryController = TextEditingController();
  RxString productType = ''.obs;

  // Optional Fields
  final TextEditingController unitController = TextEditingController();
  RxMap<String, String?> selectedUnit = {'name': '', 'id': null}.obs;
  int? unitId;

  final TextEditingController taxController = TextEditingController();
  final TextEditingController taxIDController = TextEditingController();
  final TextEditingController commissionAmountController = TextEditingController();
  RxBool isCommissionFixed = false.obs;
  final TextEditingController barcodeController = TextEditingController();
  final RxList<AdditionalPrice> additionalPrices = <AdditionalPrice>[].obs;
  final RxList<ProductProperty> properties = <ProductProperty>[].obs;
  // final RxList<ProductVariant> variants = <ProductVariant>[].obs;
  final RxMap<String, String> variantStocks = <String, String>{}.obs;
  // Map to store custom prices for variants.
  // Key: Variant Key (generated from property values)
  // Value: Map of price names to price values (e.g., {'main': 1000, 'hamkar': 900})
  final RxMap<String, Map<String, int>> variantPrices = <String, Map<String, int>>{}.obs;
  RxBool expandDetails = false.obs;
  RxList<ProductPropertyDB> availableProperties = <ProductPropertyDB>[].obs;
  ProductDetailsModel({required this.name, this.draftUid});

  String getVariantKey(List<Map> variantProperty) {
    // Sort by property UID to ensure consistent key regardless of order
    final sortedProps = List<Map>.from(variantProperty)..sort((a, b) => (a['uid'] as String).compareTo(b['uid'] as String));

    return sortedProps.map((p) => '${p['uid']}:${p['vid']}').join('|');
  }
}
