import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/models/inventory_quantity.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/popNumberPad.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_pages/invoice/add/components/model.dart';
import 'package:mik_utils/public/number.dart';

class AmountChangeInvoice extends GetView {
  late final InvoiceItemModel item;
  late final InvoiceProItemModel pro;
  late final String type, branchUID;
  late final dynamic callback;
  late final bool isEdit;
  // Separate constructors keep remote rows independent of Hive fields.
  // ignore: prefer_const_constructors_in_immutables
  AmountChangeInvoice({
    required this.item,
    required this.pro,
    required this.type,
    required this.branchUID,
    required this.callback,
    required this.isEdit,
    super.key,
  }) : remote = null;
  late final ({
    String quantity,
    bool locked,
    ValueChanged<String> onChanged,
    VoidCallback onRemove,
  })?
  remote;
  AmountChangeInvoice.remote({
    super.key,
    required String quantity,
    required bool locked,
    required ValueChanged<String> onChanged,
    required VoidCallback onRemove,
  }) {
    remote = (
      quantity: quantity,
      locked: locked,
      onChanged: onChanged,
      onRemove: onRemove,
    );
  }

  void step(int delta) {
    final row = remote!;
    try {
      final value = InventoryQuantity.fromJson(
        row.quantity.trim().toEnglishDigit().replaceAll('٫', '.'),
      ).toString();
      final parts = value.split('.');
      final scale = BigInt.from(1000000);
      final units =
          BigInt.parse(parts[0]) * scale +
          BigInt.parse((parts.length == 1 ? '' : parts[1]).padRight(6, '0')) +
          BigInt.from(delta) * scale;
      if (units <= BigInt.zero) {
        row.onRemove();
        return;
      }
      final fraction = (units % scale)
          .toString()
          .padLeft(6, '0')
          .replaceFirst(RegExp(r'0+$'), '');
      final next = '${units ~/ scale}${fraction.isEmpty ? '' : '.$fraction'}';
      InventoryQuantity.fromJson(next);
      row.onChanged(next);
    } on FormatException {
      Alert.error(
        'تعداد معتبر نیست؛ مقدار مثبت با حداکثر ۶ رقم اعشار وارد کنید.',
      );
    }
  }

  static Map<String, double> firstAmounts = {};
  String get _key => '${item.uid}_${pro.uid}';
  double get firstAmount => firstAmounts[_key] ?? 0;
  @override
  Widget build(BuildContext context) {
    final row = remote;
    if (row != null) {
      final remove = row.quantity == '1' || row.quantity.startsWith('0.');
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: row.locked ? null : () => step(1),
            child: Icon(
              IconsaxPlusBold.add_square,
              color: row.locked ? Colors.grey : AppColors.success,
            ),
          ),
          Flexible(
            child: InkWell(
              onTap: row.locked
                  ? null
                  : () => MyBottomSheet.view(
                      context,
                      title: 'تعداد',
                      child: (_) => _RemoteQuantityEditor(
                        quantity: row.quantity,
                        onChanged: row.onChanged,
                      ),
                    ),
              child: Container(
                width: 60,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.backgroundDarkMode),
                  ),
                ),
                child: Text(
                  row.quantity,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: row.locked ? null : () => step(-1),
            child: Icon(
              remove
                  ? IconsaxPlusLinear.trash_square
                  : IconsaxPlusBold.minus_square,
              color: row.locked ? Colors.grey : AppColors.error,
            ),
          ),
        ],
      );
    }
    if (isEdit) {
      firstAmounts.putIfAbsent(_key, () => pro.amount);
      // _firstAmounts[_key] = pro.amount;
    }
    return Row(
      children: [
        InkWell(
          onTap: () {
            if (type != 'pf' &&
                type != 'buy' &&
                (pro.warehouseUID == '' || pro.warehouseUID == '-') &&
                item.type != 'service') {
              Alert.warning('انبار انتخاب نشده است.');
              return;
            }
            int d = 0;
            try {
              d = pro.amount.toString().split('.')[1].length;
            } catch (_) {
              // Integers have no fractional digits.
            }

            if (type == 'sell' || type == 'w2w') {
              log(
                ProductFX.productInWarehouse(
                  item.uid,
                  pro.uid,
                  pro.warehouseUID,
                ).toString(),
              );

              if ((isEdit
                      ? (ProductFX.productInWarehouse(
                                  item.uid,
                                  pro.uid,
                                  pro.warehouseUID,
                                ) +
                                firstAmount >
                            pro.amount)
                      : (ProductFX.productInWarehouse(
                              item.uid,
                              pro.uid,
                              pro.warehouseUID,
                            ) >
                            pro.amount)) ||
                  (item.type == 'service')) {
                callback(
                  pro.uid,
                  double.parse((pro.amount + 1).toStringAsFixed(d)),
                );
              }
              if ((isEdit
                      ? (ProductFX.productInWarehouse(
                                  item.uid,
                                  pro.uid,
                                  pro.warehouseUID,
                                ) +
                                firstAmount ==
                            pro.amount)
                      : ProductFX.productInWarehouse(
                              item.uid,
                              pro.uid,
                              pro.warehouseUID,
                            ) ==
                            pro.amount) &&
                  (item.type != 'service')) {
                Alert.warning('حداکثر موجودی در این انبار انتخاب شده است.');
              }
            } else {
              callback(
                pro.uid,
                double.parse((pro.amount + 1).toStringAsFixed(d)),
              );
            }
          },
          borderRadius: BorderRadius.circular(5),
          child: Icon(
            IconsaxPlusBold.add_square,
            color:
                (type == 'sell' || type == 'w2w') &&
                    (isEdit
                        ? (ProductFX.productInWarehouse(
                                    item.uid,
                                    pro.uid,
                                    pro.warehouseUID,
                                  ) +
                                  firstAmount ==
                              pro.amount)
                        : (ProductFX.productInWarehouse(
                                item.uid,
                                pro.uid,
                                pro.warehouseUID,
                              ) ==
                              pro.amount)) &&
                    (item.type != 'service')
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.success,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => PopNumberPad.amount((v) {
              if (type == 'sell' || type == 'w2w') {
                if (ProductFX.productInWarehouse(
                      item.uid,
                      pro.uid,
                      pro.warehouseUID,
                    ) >=
                    double.parse(v)) {
                  callback(pro.uid, double.parse(v));
                } else {
                  Alert.error('مقدار انتخاب شده از موجودی انبار بیشتر است.');
                }
              } else {
                callback(pro.uid, double.parse(v));
              }
            }, initVal: pro.amount),
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.backgroundDarkMode),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                Number.addCommas(pro.amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: () {
            if (pro.amount > 0.9) {
              int d = 0;
              try {
                d = pro.amount.toString().split('.')[1].length;
              } catch (_) {
                // Integers have no fractional digits.
              }
              callback(
                pro.uid,
                double.parse((pro.amount - 1).toStringAsFixed(d)),
              );
            } else {
              callback(pro.uid, 0.0);
            }
          },
          borderRadius: BorderRadius.circular(5),
          child: Icon(
            pro.amount <= 1
                ? IconsaxPlusLinear.trash_square
                : IconsaxPlusBold.minus_square,
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _RemoteQuantityEditor extends StatefulWidget {
  final String quantity;
  final ValueChanged<String> onChanged;
  const _RemoteQuantityEditor({
    required this.quantity,
    required this.onChanged,
  });
  @override
  State<_RemoteQuantityEditor> createState() => _RemoteQuantityEditorState();
}

class _RemoteQuantityEditorState extends State<_RemoteQuantityEditor> {
  late final text = TextEditingController(text: widget.quantity);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Input(
        key: const ValueKey('invoice-quantity-editor'),
        controller: text,
        name: 'تعداد',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      BTN(
        name: 'تایید تعداد',
        onTap: () {
          try {
            final quantity = InventoryQuantity.fromJson(
              text.text.trim().toEnglishDigit().replaceAll('٫', '.'),
            );
            if (quantity.isZero) throw const FormatException('Zero quantity');
            widget.onChanged(quantity.toString());
            Get.back();
          } on FormatException {
            Alert.error(
              'تعداد معتبر نیست؛ مقدار مثبت با حداکثر ۶ رقم اعشار وارد کنید.',
            );
          }
        },
      ),
    ],
  );
}
