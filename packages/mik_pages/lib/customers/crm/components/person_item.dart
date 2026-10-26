import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_consts/svgIcon.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_data/models/models.dart';

import 'package:url_launcher/url_launcher_string.dart';

class CRMPersonItem extends GetView {
  PersonDB item;

  // ignore: prefer_typing_uninitialized_variables
  var callBack;
  CRMPersonItem(this.item, this.callBack, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Get.toNamed(RoutesName.CUSTOMERDETAIL, arguments: {'item': item});
        callBack('v');
      },
      child: Column(
        children: [
          SwipeActionCell(
            key: Key(item.id.toString()),
            backgroundColor: Colors.transparent,
            index: item.id,
            firstActionWillCoverAllSpaceOnDeleting: false,
            closeWhenScrolling: false,
            trailingActions: [
              SwipeAction(
                title: 'ثبت ارتباط',
                style: const TextStyle(fontSize: 10, color: Colors.white),
                icon: const Icon(
                  IconsaxPlusLinear.call_add,
                  color: Colors.white,
                ),
                backgroundRadius: 10,
                color: AppColors.secondary,
                widthSpace: 50,
                forceAlignmentToBoundary: true,
                performsFirstActionWithFullSwipe: false,
                onTap: (v) {
                  v(false);
                },
              ),
              SwipeAction(
                title: 'کدتخفیف',
                style: const TextStyle(fontSize: 10, color: Colors.white),
                icon: const Icon(
                  IconsaxPlusLinear.discount_shape,
                  color: Colors.white,
                ),
                backgroundRadius: 10,
                color: AppColors.blue,
                widthSpace: 50,
                forceAlignmentToBoundary: true,
                performsFirstActionWithFullSwipe: false,
                onTap: (v) {
                  v(false);
                },
              ),
              SwipeAction(
                title: 'ارسال پیامک',
                style: const TextStyle(fontSize: 10, color: Colors.white),
                icon: const Icon(
                  IconsaxPlusLinear.message_add,
                  color: Colors.white,
                ),
                backgroundRadius: 10,
                color: AppColors.yellow,
                widthSpace: 50,
                forceAlignmentToBoundary: true,
                performsFirstActionWithFullSwipe: false,
                onTap: (v) {
                  v(false);
                },
              ),
              SwipeAction(
                title: 'تماس',
                style: const TextStyle(fontSize: 10, color: Colors.white),
                icon: const Icon(IconsaxPlusLinear.call, color: Colors.white),
                backgroundRadius: 10,
                color: AppColors.secondary,
                widthSpace: 50,
                forceAlignmentToBoundary: true,
                performsFirstActionWithFullSwipe: false,
                onTap: (v) {
                  v(false);
                  launchUrlString('tel://${item.mobile}');
                },
              ),
              SwipeAction(
                title: 'وضعیت مالی',
                style: const TextStyle(fontSize: 10, color: Colors.white),
                icon: const Icon(
                  IconsaxPlusLinear.money_change,
                  color: Colors.white,
                ),
                backgroundRadius: 10,
                color: AppColors.primary,
                widthSpace: 50,
                forceAlignmentToBoundary: true,
                performsFirstActionWithFullSwipe: false,
                onTap: (v) {
                  v(false);
                },
              ),
            ],
            leadingActions: const [],
            child: Container(
              padding: const EdgeInsets.only(
                top: 5,
                bottom: 5,
                right: 20,
                left: 10,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.boxBackground,
                    child: item.org == true
                        ? SvgPicture.asset(SvgIcon.orgCustomer)
                        : SvgPicture.asset(SvgIcon.customer),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            item.name!,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'آخرین خرید: ${DateConvertor.grigoriToJalali(InvoiceFX.lastDate(item.uid!))}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          EndLine(),
        ],
      ),
    );
  }
}
