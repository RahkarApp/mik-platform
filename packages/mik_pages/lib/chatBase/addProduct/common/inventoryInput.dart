import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_pages/chatBase/addProduct/common/detailsModel.dart';
import 'package:mik_pages/chatBase/addProduct/common/productProperty.dart';

class InventoryInput extends StatelessWidget {
  final TextEditingController controller;
  final String name;
  final Function(String)? onChanged;

  const InventoryInput(
      {super.key, required this.controller, required this.name, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            int val = int.tryParse(controller.text) ?? 0;
            controller.text = (val + 1).toString();
            if (onChanged != null) onChanged!(controller.text);
          },
          child: Icon(IconsaxPlusLinear.add_square),
        ),
        Expanded(
          child: Input(
            controller: controller,
            keyboardType: TextInputType.number,
            name: name,
            textAlign: TextAlign.center,
            onChanged: onChanged,
          ),
        ),
        InkWell(
          onTap: () {
            int val = int.tryParse(controller.text) ?? 0;
            if (val > 0) {
              controller.text = (val - 1).toString();
              if (onChanged != null) onChanged!(controller.text);
            }
          },
          child: Icon(IconsaxPlusLinear.minus_square),
        ),
      ],
    );
  }

  void addExistingFeature(
      ProductDetailsModel product, ProductPropertyDB property) {
    ProductProperty feature = ProductProperty();
    feature.name = property.name;
    feature.uid = property.uid;

    // We don't pre-populate values, user selects them. Or maybe we should?
    // The user said "uid اون ویژگی که انتخاب میکنه با value هاش هم نام و هم id باید توی products نگه داریم"
    // This implies we keep the POTENTIAL values or SELECTED values?
    // Usually when adding a feature, we start empty and add values.
    // But if we want to restrict to existing values, we might need a different UI.
    // For now, let's just set the UID and name.
    // If the user adds a value that matches an existing one, we should link it.
    // Actually, let's populate valuesWithId with ALL available values for this property
    // so we can look them up when the user adds them.

    for (var v in property.value) {
      feature.valuesWithId.add(v as Map<String, dynamic>);
    }

    product.properties.add(feature);
    Get.back(); // Close the sheet
  }
}
