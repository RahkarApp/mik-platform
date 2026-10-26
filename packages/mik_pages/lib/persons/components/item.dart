// ignore_for_file: prefer_typing_uninitialized_variables, empty_catches

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_consts/svgIcon.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/number.dart';

class PersonItem extends GetView {
  PersonDB item;
  String type;
  bool end;
  var callback;
  PersonItem(this.item, this.end, this.type, {this.callback, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            await Get.toNamed(route(), arguments: {'item': item});
            try {
              callback('v');
            } catch (e) {}
          },
          child: Column(
            children: [
              Container(
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
                      maxRadius: 25,
                      child: icon(),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text.rich(
                                  TextSpan(
                                    text: item.org!
                                        ? item.orgName!
                                        : item.name!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      if (item.org!)
                                        TextSpan(
                                          text: ' (${item.name})',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              Text(item.mobile ?? ''),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (type == 'customer')
                                Text(
                                  'آخرین خرید: ${DateConvertor.grigoriToJalali(InvoiceFX.lastDate(item.uid!))}',
                                  maxLines: 1,
                                ),
                              SizedBox(width: 5),

                              if (type != 'partner')
                                Flexible(
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      Number.numberPlus(
                                        AccountingFX.findPersonFinancial(
                                          item.uid!,
                                        ),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        color:
                                            AccountingFX.findPersonFinancial(
                                                  item.uid!,
                                                ) >
                                                0
                                            ? AppColors.blue
                                            : AccountingFX.findPersonFinancial(
                                                    item.uid!,
                                                  ) ==
                                                  0
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ),
                              if (type != 'partner')
                                Text(
                                  Number.financialWithoutNumber(
                                    AccountingFX.findPersonFinancial(item.uid!),
                                  ),
                                  style: TextStyle(
                                    color:
                                        AccountingFX.findPersonFinancial(
                                              item.uid!,
                                            ) >
                                            0
                                        ? AppColors.blue
                                        : AccountingFX.findPersonFinancial(
                                                item.uid!,
                                              ) ==
                                              0
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!end) EndLine(),
            ],
          ),
        ),
        if (end) SizedBox(height: 55),
      ],
    );
  }

  Color color() {
    switch (type) {
      case 'partner':
        return AppColors.primary;
      case 'marketer':
        return AppColors.yellow;
      case 'servicer':
        return AppColors.blue;
      case 'supplier':
        return AppColors.success;
      case 'customer':
        return AppColors.secondary;

      default:
        return Colors.white;
    }
  }

  Widget icon() {
    switch (type) {
      case 'partner':
        return SvgPicture.asset(SvgIcon.partner, height: 40);
      case 'marketer':
        return SvgPicture.asset(SvgIcon.mikyar, height: 40);
      case 'servicer':
        return SvgPicture.asset(SvgIcon.servicer, height: 40);
      case 'supplier':
        return SvgPicture.asset(SvgIcon.supplier, height: 40);
      case 'customer':
        return item.org == true
            ? SvgPicture.asset(SvgIcon.orgCustomer, height: 40)
            : SvgPicture.asset(SvgIcon.customer, height: 40);
      default:
        return SvgPicture.asset(SvgIcon.customer, height: 40);
    }
  }

  route() {
    switch (type) {
      case 'partner':
        return RoutesName.PARTNERDETAIL;
      case 'marketer':
        return RoutesName.MIKWAY_MIKYARDET;
      case 'servicer':
        return RoutesName.SERVICERDETAIL;
      case 'supplier':
        return RoutesName.SUPPLIERDETAIL;
      case 'customer':
        return RoutesName.CUSTOMERDETAIL;

      default:
        return Colors.white;
    }
  }
}
