import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/public/date.dart';

class CRMConnectionItem extends GetView {
  ConnectionDB item;
  bool? cmScreen;
  CRMConnectionItem(this.item, {this.cmScreen, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => tap(context, item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  maxRadius: 25,
                  backgroundColor: AppColors.boxBackground,
                  child: Icon(
                    item.result
                        ? IconsaxPlusLinear.like_1
                        : IconsaxPlusLinear.dislike,
                    color: item.result ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  fit: FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cmScreen ?? false
                            ? item.desc
                            : PersonFX.findByUID(item.personUID).name,
                        style: TextStyle(
                          fontWeight: cmScreen ?? false
                              ? FontWeight.normal
                              : FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            (item.nextDate != null && item.nextDate != '')
                                ? 'پیگیری مجدد در: ${DateConvertor.grigoriToJalali(item.nextDate)}'
                                : '',
                          ),
                          if (item.status != '')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Text(item.status!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(DateConvertor.grigoriToJalali(item.date)),
                    Text(item.date!.split('T')[1].substring(0, 5)),
                  ],
                ),
              ],
            ),
          ),
        ),
        EndLine(),
      ],
    );
  }

  tap(context, item) {
    List aginDone = connection.values
        .where((e) => e.parent == item.uid && item.uid != e.uid)
        .toList();
    MyBottomSheet.view(
      context,
      child: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            Text(item.desc!, textAlign: TextAlign.justify),
            if (item.nextDate != null && item.nextDate != '')
              (aginDone.isEmpty)
                  ? Column(
                      children: [
                        MyDivider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'پیگیری مجدد:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${item.nextDate!.split('T')[1].substring(0, 5)} ${DateConvertor.grigoriToJalali(item.nextDate)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (PermissionFx.isAddCRM())
                          BTN(
                            onTap: () {
                              Get.toNamed(
                                RoutesName.CRMCONNETCIONADD,
                                arguments: {
                                  'puid': item.personUID,
                                  'pname': PersonFX.findByUID(item.personUID)
                                      .name,
                                  'parentUID': item.uid,
                                },
                              );
                            },
                            name: 'ثبت پیگیری جدید',
                          ),
                      ],
                    )
                  : Column(
                      children: [
                        MyDivider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'پیگیری مجدد انجام شده در:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${aginDone[0].date!.split('T')[1].substring(0, 5)} ${DateConvertor.grigoriToJalali(aginDone[0].date)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        BTN(
                          onTap: () {
                            tap(context, aginDone[0]);
                          },
                          name: 'مشاهده نتیجه پیگیری',
                        ),
                      ],
                    ),
          ],
        ),
      ),
      title:
          'زمان پیگیری: ${item.date!.split('T')[1].substring(0, 5)} ${DateConvertor.grigoriToJalali(item.date)}',
    );
  }
}
