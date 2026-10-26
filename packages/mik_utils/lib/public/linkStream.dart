// ignore_for_file: empty_catches, constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_variables/variable.dart';
import 'package:app_links/app_links.dart';
import 'package:mik_components/elements/bottomSheet.dart';

import 'package:mik_consts/colors.dart';

final _appLinks = AppLinks();

enum LinkStreamType { MiKifDeposit }

class LinkStream {
  static listen(context, {required LinkStreamType type}) {
    linkStream = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        cancel();
        if (LinkStreamType.MiKifDeposit == type) {
          showResMiKifDeposit(context, uri!.queryParameters);
        }
      },
      onError: (e) {
        cancel();
      },
    );
  }

  static cancel() {
    try {
      linkStream!.cancel();
    } catch (e) {}
  }

  static showResMiKifDeposit(context, Map<String, String> query) async {
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          if (query['IsSuccess'].toString() != 'true')
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  IconsaxPlusLinear.close_circle,
                  color: Colors.red,
                  size: 70,
                ),
                const SizedBox(height: 30),
                const Text(
                  'شارژ میکیف انجام نشد!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                BTN(
                  name: 'بستن',
                  type: BTNType.cancel,
                  icon: IconsaxPlusLinear.receipt,
                  onTap: () => Get.back(),
                ),
              ],
            ),
          if (query['IsSuccess'].toString() == 'true')
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  IconsaxPlusLinear.tick_circle,
                  color: AppColors.success,
                  size: 70,
                ),
                const SizedBox(height: 30),
                const Text(
                  'شارژ میکیف با موفقیت انجام شد.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                BTN(
                  name: 'بستن',
                  type: BTNType.cancel,
                  icon: IconsaxPlusLinear.receipt,
                  onTap: () => Get.back(),
                ),
              ],
            ),
        ],
      ),
      //h: 250,
      showClose: false,
      title: 'پرداخت موفق',
      isDismissible: false,
    );
  }
}
