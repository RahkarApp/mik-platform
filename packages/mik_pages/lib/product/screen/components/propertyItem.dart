import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_utils/public/color.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/source/remote/models/models.dart';

import '../tabs/controllers/property.dart';

class PropertyItem extends StatelessWidget {
  final PimAttribute item;
  final ProductPropertyTabDashboardController controller;
  final VoidCallback onEdit;
  const PropertyItem(
    this.item, {
    super.key,
    required this.controller,
    required this.onEdit,
  });
  IconData get icon => switch (item.kind) {
    'COLOR' => IconsaxPlusLinear.color_swatch,
    'PART_NUMBER' => IconsaxPlusLinear.setting_3,
    'SIZE' => IconsaxPlusLinear.ruler,
    _ => IconsaxPlusLinear.shapes_1,
  };
  Widget heading() => Row(
    children: [
      const SizedBox(width: 10),
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.boxBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 25, color: AppColors.disable),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text('${item.values.length} مقدار'),
          ],
        ),
      ),
      const SizedBox(width: 10),
    ],
  );
  Color? color(PimOption option) {
    final hex = option.colorHex;
    return hex != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)
        ? Color(int.parse('FF${hex.substring(1)}', radix: 16))
        : null;
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => tap(context),
    child: Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: heading(),
        ),
        EndLine(),
      ],
    ),
  );
  void tap(BuildContext context) {
    MyBottomSheet.view(
      context,
      title: '',
      child: (scroll) => SingleChildScrollView(
        controller: scroll,
        child: Column(
          children: [
            heading(),
            const SizedBox(height: 10),
            Text(
              ProductPropertyTabDashboardController.types[item.dataType] ??
                  item.dataType,
            ),
            Text(
              item.usableForVariant
                  ? 'قابل استفاده در ساخت تنوع'
                  : 'ویژگی مشخصات محصول',
            ),
            MyDivider(text: 'مقادیر'),
            Wrap(
              children: [
                for (final option in item.values)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: item.kind == 'COLOR' ? color(option) : null,
                      border: Border.all(
                        color: item.kind == 'COLOR' && color(option) != null
                            ? color(option)!
                            : darkMode.value
                            ? Colors.white
                            : Colors.black,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${option.name}${option.active ? '' : ' (غیرفعال)'}',
                      style: TextStyle(
                        color: item.kind == 'COLOR' && color(option) != null
                            ? (isColorDark(color(option)!)
                                  ? Colors.white
                                  : Colors.black)
                            : darkMode.value
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            Obx(
              () => Row(
                children: [
                  if (controller.canEdit(item))
                    MiniBTN(
                      name: 'ویرایش',
                      flex: 4,
                      color: darkMode.value
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                      itemColor: darkMode.value
                          ? Colors.grey.shade300
                          : Colors.grey.shade800,
                      icon: IconsaxPlusLinear.edit_2,
                      onTap: () {
                        Get.back();
                        onEdit();
                      },
                    ),
                  if (controller.canStatus(item))
                    MiniBTN(
                      name: item.status == 'ACTIVE' ? 'آرشیو' : 'فعال‌سازی',
                      color: darkMode.value
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                      itemColor: AppColors.error,
                      icon: IconsaxPlusLinear.trash,
                      onTap: () => Confirm.con(
                        context,
                        type: ConfirmType.CHANGE,
                        subtext: item.status == 'ACTIVE'
                            ? 'ویژگی آرشیو شود؟ سرور استفاده‌شدن آن در محصولات را بررسی می‌کند.'
                            : 'ویژگی دوباره فعال شود؟',
                        confirmText: item.status == 'ACTIVE'
                            ? 'آرشیو ویژگی'
                            : 'فعال‌سازی ویژگی',
                        onTapConfirm: () async {
                          Get.back();
                          Get.back();
                          await controller.changeStatus(item);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
