import 'package:flutter/material.dart';

class AdditionalPrice {
  TextEditingController nameController;
  TextEditingController priceController;
  String? uid;
  AdditionalPrice(
      {required this.nameController, required this.priceController, this.uid});
}
