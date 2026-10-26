import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/scanner.dart';
import 'package:mik_consts/colors.dart';

final s = TextEditingController();
final f = FocusNode();

enum SearchBarType {
  product,
  productProperty,
  warehouse,
  category,
  user,
  crm,
  bank,
  unit,
  report,
  campain,
  cost,
  branch,
  text,
}

class MySearchBarController {
  static unfoces() {
    f.unfocus();
    s.clear();
  }
}

class MySearchBar extends GetView {
  SearchBarType type;
  ValueSetter callback;
  String? hintText;
  final bool enableScanner;
  @override
  TextEditingController? controller;
  FocusNode? focusNode;

  MySearchBar({
    this.hintText,
    this.enableScanner = true,
    required this.type,
    required this.callback,
    this.controller,
    this.focusNode,
    super.key,
  });

  String hint() {
    switch (type) {
      case SearchBarType.product:
        return 'برای جستجو کد، بارکد و یا نام کالا را وارد کنید...';
      case SearchBarType.productProperty:
        return 'برای جستجو نام ویژگی را وارد کنید...';
      case SearchBarType.category:
        return 'برای جستجو کد، یا نام دسته‌بندی را وارد کنید...';
      case SearchBarType.warehouse:
        return 'برای جستجو کد، یا نام انبار را وارد کنید...';
      case SearchBarType.user:
        return 'برای جستجو نام یا موبایل مشتری را وارد کنید...';
      case SearchBarType.crm:
        return 'برای جستجو نام یا توضیحات را وارد کنید...';
      case SearchBarType.campain:
        return 'برای جستجو کد یا نام کمپین را وارد کنید...';
      case SearchBarType.cost:
        return 'برای جستجو کد یا عنوان هزینه را وارد کنید...';
      case SearchBarType.unit:
        return 'برای جستجو واحد را وارد کنید...';
      case SearchBarType.bank:
        return 'برای جستجو کد یا نام بانک را وارد کنید...';
      case SearchBarType.report:
        return 'برای جستجو نام گزارش را وارد کنید...';
      case SearchBarType.branch:
        return 'برای جستجو نام شعبه را وارد کنید...';
      case SearchBarType.text:
        return 'جستجو...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller ?? s,
      style: 2,
      focusNode: focusNode ?? f,
      name: '',
      rightPadding: 0,
      fillColor: AppColors.boxBackground,
      hintText: hintText ?? hint(),
      onChanged: (v) => callback(v),
      suffixIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        width: 71,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: () async {
                f.unfocus();
              },
              child: const Icon(IconsaxPlusLinear.search_normal_1),
            ),
            if (SearchBarType.product == type) const SizedBox(width: 15),
            if (SearchBarType.product == type)
              InkWell(
                onTap: !enableScanner
                    ? null
                    : () async {
                        f.unfocus();
                        var st = await Scanner.barcode(context);
                        if (st != null && st != '' && st != '-1')
                          controller == null
                              ? s.text = st
                              : controller!.text = st;
                        callback(st);
                      },
                child: enableScanner
                    ? const Icon(IconsaxPlusLinear.scan)
                    : const Tooltip(
                        message: 'جست‌وجو با بارکد فعلاً در دسترس نیست.',
                        child: Icon(IconsaxPlusLinear.scan),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
