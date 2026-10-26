// ignore_for_file: void_checks

import 'package:auto_size_text_plus/auto_size_text_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import 'package:mik_consts/colors.dart';

import 'buttons/button.dart';

String _temp1 = '0';
String _temp2 = '0';
String _operation = '';
bool _initItem = true;

class PopNumberPad {
  static amount(callback, {initVal}) {
    return full(
      (v) {
        callback(v);
      },
      txt: 'تعداد',
      opt: false,
      initVal: initVal,
    );
  }

  static price({
    required callback,
    required bool isBuy,
    required String productUID,
    required String prouid,
    initVal,
  }) {
    return full(
      (v) {
        callback(v);
      },
      txt: isBuy ? 'قیمت خرید محصول' : 'قیمت فروش محصول',
      isBuy: isBuy,
      opt: true,
      sellPriceList: productPrice.values
          .where((element) => element.puid == productUID)
          .toList(),
      productUID: productUID,
      prouid: prouid,
      initVal: initVal,
    );
  }

  static setPrice({
    required callback,
    required String header,
    required String subHeader,
    initVal,
  }) {
    return full(
      (v) {
        callback(v);
      },
      txt: header,
      subTXT: subHeader,
      isBuy: false,
      //opt: false,
      sellPriceList: null,
      initVal: initVal,
    );
  }

  static void _keyboardPress(String val, RxString res, dynamic initVal) {
    if (val == 'C') {
      _temp1 = '0';
      _temp2 = '0';
      _operation = '';
      res.value = '0';
      return;
    } else if (val == '=') {
      if (_operation != '') {
        var result = _calculate(
          double.tryParse(_temp1) ?? double.parse(_temp1.split('-')[0]),
          double.tryParse(_temp2) ?? double.parse(_temp2.split('-')[0]),
          double.tryParse(_temp1) == null,
          double.tryParse(_temp2) == null,
          _operation,
        ).toString();

        _operation = '';
        _temp1 = result;
        _temp2 = '0';

        res.value = Number.addCommas(double.parse(result));
      }

      return;
    } else if (double.tryParse(val) == null) {
      if (val == '.') {
        _temp1 = _temp1.contains('.') ? _temp1 : '$_temp1.';

        res.value = _temp1;
      } else {
        _operation = val;
      }

      return;
    } else {
      if (_initItem && _temp1 == initVal && _operation == '') {
        _temp1 = '0';
        _initItem = false;
      }

      if (_operation == '') {
        _temp1 = _temp1 != '0' ? _temp1 + val : val;

        res.value = Number.addCommas(double.parse(_temp1));
      } else {
        _temp2 = _temp2 != '0' ? _temp2 + val : val;

        res.value = Number.addCommas(double.parse(_temp2));
      }
    }
  }

  // static number() {}
  static full(
    callback, {
    opt = true,
    initVal,
    String txt = '',
    String? subTXT,
    String? productUID,
    String? prouid,
    bool? isBuy,
    List<ProductPriceDB>? sellPriceList,
  }) {
    RxString res = ''.obs;
    initVal = Number.addCommas(initVal);
    _initItem = true;
    _temp1 = '0';
    _temp2 = '0';
    if (initVal != null) {
      _temp1 = initVal.toString().replaceAll(',', '');
      res.value = initVal;
    }
    _operation = '';
    bool red = sellPriceList != null && sellPriceList != []
        ? ProductFX.lastBuyPrice(productUID!, prouid ?? '-') >
              Price.toInt(initVal)
        : false;
    //this Dialog is OK
    Get.dialog(
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (RawKeyEvent event) {
              if (event is! RawKeyDownEvent) return;

              final key = event.logicalKey;

              // numbers
              if (key == LogicalKeyboardKey.digit0 ||
                  key == LogicalKeyboardKey.numpad0) {
                _keyboardPress('0', res, initVal);
              } else if (key == LogicalKeyboardKey.digit1 ||
                  key == LogicalKeyboardKey.numpad1) {
                _keyboardPress('1', res, initVal);
              } else if (key == LogicalKeyboardKey.digit2 ||
                  key == LogicalKeyboardKey.numpad2) {
                _keyboardPress('2', res, initVal);
              } else if (key == LogicalKeyboardKey.digit3 ||
                  key == LogicalKeyboardKey.numpad3) {
                _keyboardPress('3', res, initVal);
              } else if (key == LogicalKeyboardKey.digit4 ||
                  key == LogicalKeyboardKey.numpad4) {
                _keyboardPress('4', res, initVal);
              } else if (key == LogicalKeyboardKey.digit5 ||
                  key == LogicalKeyboardKey.numpad5) {
                _keyboardPress('5', res, initVal);
              } else if (key == LogicalKeyboardKey.digit6 ||
                  key == LogicalKeyboardKey.numpad6) {
                _keyboardPress('6', res, initVal);
              } else if (key == LogicalKeyboardKey.digit7 ||
                  key == LogicalKeyboardKey.numpad7) {
                _keyboardPress('7', res, initVal);
              } else if (key == LogicalKeyboardKey.digit8 ||
                  key == LogicalKeyboardKey.numpad8) {
                _keyboardPress('8', res, initVal);
              } else if (key == LogicalKeyboardKey.digit9 ||
                  key == LogicalKeyboardKey.numpad9) {
                _keyboardPress('9', res, initVal);
              }
              // operators
              else if (key == LogicalKeyboardKey.add ||
                  key == LogicalKeyboardKey.equal ||
                  key == LogicalKeyboardKey.numpadAdd) {
                _keyboardPress('+', res, initVal);
              } else if (key == LogicalKeyboardKey.minus ||
                  key == LogicalKeyboardKey.numpadSubtract ||
                  key == LogicalKeyboardKey.minus) {
                _keyboardPress('-', res, initVal);
              } else if (key == LogicalKeyboardKey.slash ||
                  key == LogicalKeyboardKey.numpadDivide ||
                  key == LogicalKeyboardKey.slash) {
                _keyboardPress('÷', res, initVal);
              } else if (key == LogicalKeyboardKey.numpadMultiply) {
                _keyboardPress('×', res, initVal);
              }
              // decimal
              else if (key == LogicalKeyboardKey.period ||
                  key == LogicalKeyboardKey.numpadDecimal) {
                _keyboardPress('.', res, initVal);
              }
              // enter
              else if (key == LogicalKeyboardKey.enter ||
                  key == LogicalKeyboardKey.numpadEnter) {
                // اگر عملیات وجود داشت
                if (_operation != '' && _temp2 != '0') {
                  var result = _calculate(
                    double.tryParse(_temp1) ??
                        double.parse(_temp1.split('-')[0]),
                    double.tryParse(_temp2) ??
                        double.parse(_temp2.split('-')[0]),
                    double.tryParse(_temp1) == null,
                    double.tryParse(_temp2) == null,
                    _operation,
                  ).toString();

                  _temp1 = result;
                  _temp2 = '0';
                  _operation = '';

                  res.value = Number.addCommas(double.parse(result));

                  return;
                }

                // اگر عملیات نداشت => تایید نهایی
                callback(res.value.replaceAll(',', ''));
                Get.back();
              }
              // backspace
              else if (key == LogicalKeyboardKey.backspace) {
                String txt = res.value.replaceAll(',', '');

                if (txt.isNotEmpty) {
                  txt = txt.substring(0, txt.length - 1);

                  if (txt.isEmpty) {
                    txt = '0';
                  }

                  if (_operation == '') {
                    _temp1 = txt;
                  } else {
                    _temp2 = txt;
                  }

                  res.value = Number.addCommas(double.parse(txt));
                }
              }
              // escape
              else if (key == LogicalKeyboardKey.escape) {
                Get.back();
              }
            },
            child: Material(
              color: darkMode.value
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (productUID != null)
                    Container(
                      padding: EdgeInsets.only(top: 4, bottom: 4),
                      color: red ? Colors.red : null,
                      width: (isBuy ?? false) || sellPriceList == null
                          ? Responsive.isMobile(Get.context!)
                                ? Get.width * 0.7
                                : 500
                          : Responsive.isMobile(Get.context!)
                          ? Get.width * 0.9
                          : 700,
                      alignment: Alignment.center,
                      child: Text(
                        (isBuy ?? true)
                            ? 'آخرین قیمت خرید: ${Price.showWithCurrency(ProductFX.lastBuyPrice(productUID, prouid ?? '-'))}'
                            : 'آخرین قیمت فروش: ${Price.showWithCurrency(ProductFX.lastSellPrice(productUID, prouid ?? '-'))}',
                        style: TextStyle(
                          color: red ? Colors.white : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Container(
                    alignment: Alignment.center,
                    height: (subTXT != null) ? 455 : 430,
                    width: (isBuy ?? false) || sellPriceList == null
                        ? Responsive.isMobile(Get.context!)
                              ? Get.width * 0.7
                              : 500
                        : Responsive.isMobile(Get.context!)
                        ? Get.width * 0.9
                        : 700,
                    decoration: BoxDecoration(
                      color: darkMode.value
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                    child: Row(
                      children: [
                        if (!(isBuy ?? false) &&
                            sellPriceList != null &&
                            sellPriceList != [])
                          Container(
                            width: Responsive.isMobile(Get.context!)
                                ? Get.width * 0.3
                                : 120,
                            height: 420,
                            margin: const EdgeInsets.only(right: 10),
                            child: Column(
                              children: [
                                Container(
                                  // padding: const EdgeInsets.only(top: 4),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'قیمت‌ها',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        for (
                                          int i = 0;
                                          i < sellPriceList.length;
                                          i++
                                        )
                                          InkWell(
                                            onTap: () {
                                              callback(
                                                (sellPriceList[i].pro != null
                                                        ? sellPriceList[i]
                                                                  .pro![prouid] ??
                                                              sellPriceList[i]
                                                                  .price
                                                        : sellPriceList[i]
                                                              .price)
                                                    .toString(),
                                              );
                                              Get.back();
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                color:
                                                    sellPriceList[i]
                                                        .defaultPrice
                                                    ? AppColors.secondary
                                                    : AppColors.primary,
                                              ),
                                              height: 50,
                                              margin: EdgeInsets.only(
                                                bottom: 5,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    sellPriceList[i].name!,
                                                    style: TextStyle(
                                                      height: 0.7,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  Divider(
                                                    indent: 5,
                                                    endIndent: 5,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                  AutoSizeText(
                                                    Price.showWithCurrency(
                                                      (sellPriceList[i].pro !=
                                                              null
                                                          ? sellPriceList[i]
                                                                    .pro![prouid] ??
                                                                sellPriceList[i]
                                                                    .price
                                                          : sellPriceList[i]
                                                                .price),
                                                    ),
                                                    maxLines: 1,
                                                    maxFontSize: 14,
                                                    minFontSize: 10,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      height: 0.7,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // BTN(
                                        //     onTap: () {
                                        //       callback((sellPriceList[i].pro![prouid] ?? sellPriceList[i].price).toString());
                                        //       Get.back();
                                        //     },
                                        //     name: Price.showWithCurrency(sellPriceList[i].pro![prouid] ?? sellPriceList[i].price) + (sellPriceList[i].defaultPrice ? '*' : '')),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!(isBuy ?? false) &&
                            sellPriceList != null &&
                            sellPriceList != [])
                          const VerticalDivider(),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            spacing: 5,
                            children: [
                              Text(
                                txt,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (subTXT != null)
                                Text(
                                  subTXT,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              Container(
                                height: 70,
                                width:
                                    sellPriceList != null && sellPriceList != []
                                    ? Responsive.isMobile(Get.context!)
                                          ? Get.width * 0.6
                                          : 300
                                    : Responsive.isMobile(Get.context!)
                                    ? Get.width * 0.7
                                    : 500,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                margin: EdgeInsets.only(
                                  bottom: 5,
                                  left: 15,
                                  right:
                                      sellPriceList != null &&
                                          sellPriceList != []
                                      ? 10
                                      : 15,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: darkMode.value
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade200,
                                ),
                                child: Obx(
                                  () => AutoSizeText(
                                    res.value,
                                    maxFontSize: 35,
                                    style: TextStyle(fontSize: 35),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.only(
                                  right:
                                      sellPriceList != null &&
                                          sellPriceList != []
                                      ? 5
                                      : 10,
                                  left: 10,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        if (opt)
                                          Flexible(
                                            flex: 1,
                                            fit: FlexFit.tight,
                                            child: _item(
                                              '÷',
                                              (v) {
                                                res.value = Number.addCommas(
                                                  double.parse(v),
                                                );
                                              },
                                              initVal,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        if (opt)
                                          Flexible(
                                            flex: 1,
                                            fit: FlexFit.tight,
                                            child: _item(
                                              '٪',
                                              (v) {
                                                res.value = Number.addCommas(
                                                  double.parse(v),
                                                );
                                              },
                                              initVal,
                                              color: AppColors.secondary,
                                              // AppColors.yellow
                                              //     .withValues(alpha:0.7)
                                            ),
                                          ),
                                        Flexible(
                                          flex: 2,
                                          fit: FlexFit.tight,
                                          child: _item('C', (v) {
                                            res.value = '0';
                                          }, initVal),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (opt)
                                          Flexible(
                                            flex: 1,
                                            fit: FlexFit.tight,
                                            child: _item(
                                              '×',
                                              (v) {
                                                res.value = Number.addCommas(
                                                  double.parse(v),
                                                );
                                              },
                                              initVal,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('9', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('8', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('7', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (opt)
                                          Flexible(
                                            flex: 1,
                                            fit: FlexFit.tight,
                                            child: _item(
                                              '-',
                                              (v) {
                                                res.value = v;
                                              },
                                              initVal,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('6', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('5', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('4', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (opt)
                                          Flexible(
                                            flex: 1,
                                            fit: FlexFit.tight,
                                            child: _item(
                                              '+',
                                              (v) {
                                                res.value = Number.addCommas(
                                                  double.parse(v),
                                                );
                                              },
                                              initVal,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('3', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('2', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('1', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (opt)
                                          Flexible(
                                            flex: 2,
                                            fit: FlexFit.tight,
                                            child: _item(
                                              '=',
                                              (v) {
                                                res.value = Number.addCommas(
                                                  double.parse(v),
                                                );
                                              },
                                              initVal,
                                              color: Colors.white,
                                              bgcolor: AppColors.secondary,
                                            ),
                                          ),
                                        Flexible(
                                          flex: 1,
                                          fit: FlexFit.tight,
                                          child: _item('.', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                        Flexible(
                                          flex: !opt ? 2 : 1,
                                          fit: FlexFit.tight,
                                          child: _item('0', (v) {
                                            res.value = Number.addCommas(
                                              double.parse(v),
                                            );
                                          }, initVal),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: BTN(
                                            name: 'تایید',
                                            color: AppColors.primary,
                                            textColor: Colors.white,
                                            onTap: () {
                                              if (_temp1 != '0' &&
                                                  _temp2 != '0') {
                                                res.value = Number.addCommas(
                                                  _calculate(
                                                    double.tryParse(_temp1) ??
                                                        double.parse(
                                                          _temp1.split('-')[0],
                                                        ),
                                                    double.tryParse(_temp2) ??
                                                        int.parse(
                                                          _temp2.split('-')[0],
                                                        ),
                                                    double.tryParse(_temp1) ==
                                                            null
                                                        ? true
                                                        : false,
                                                    double.tryParse(_temp2) ==
                                                            null
                                                        ? true
                                                        : false,
                                                    _operation,
                                                  ),
                                                );
                                              }
                                              callback(
                                                res.value.replaceAll(',', ''),
                                              );
                                              Get.back();
                                            },
                                          ),
                                        ),
                                        Flexible(
                                          child: BTN(
                                            name: 'انصراف',
                                            borderOnly: true,
                                            color: AppColors.grey,
                                            textColor: darkMode.value
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                            onTap: () => Get.back(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}

_item(val, calback, initVal, {bgcolor, color}) {
  bgcolor ??= darkMode.value ? Colors.grey.shade600 : Colors.grey.shade200;

  // if (!_initItem && initVal != null) {
  return InkWell(
    onTap: () {
      if (val == 'C') {
        _temp1 = '0';
        _temp2 = '0';
        _operation = '';
        return calback('');
      } else if (val == '=') {
        if (_operation != '') {
          var res = _calculate(
            double.tryParse(_temp1) ?? double.parse(_temp1.split('-')[0]),
            double.tryParse(_temp2) ?? double.parse(_temp2.split('-')[0]),
            double.tryParse(_temp1) == null ? true : false,
            double.tryParse(_temp2) == null ? true : false,
            _operation,
          ).toString();
          _operation = '';
          _temp1 = res;
          _temp2 = '0';
          calback(res.toString());
        }
      } else if (double.tryParse(val) == null) {
        if (val == '٪') {
          _temp2 = (((int.parse(_temp2) / 100) * int.parse(_temp1)))
              .toStringAsFixed(0);
          _temp1 = _calculate(
            double.tryParse(_temp1) ?? double.parse(_temp1.split('-')[0]),
            double.tryParse(_temp2) ?? double.parse(_temp2.split('-')[0]),
            double.tryParse(_temp1) == null ? true : false,
            double.tryParse(_temp2) == null ? true : false,
            _operation == '' ? val : _operation,
          ).toString();
          _operation = '';
          _temp2 = '0';
          calback(_temp1);
        } else if (val == '.') {
          _temp1 = _temp1.contains('.') ? _temp1 : '$_temp1.';
          _operation = '';
          _temp2 = '0';
          calback(_temp1);
        } else if (_temp1 != '0') {
          String res = _temp1;
          if (_operation != '' && _temp1 != '0' && _temp2 != '0') {
            res = _calculate(
              double.tryParse(_temp1) ?? double.parse(_temp1.split('-')[0]),
              double.tryParse(_temp2) ?? double.parse(_temp2.split('-')[0]),
              double.tryParse(_temp1) == null ? true : false,
              double.tryParse(_temp2) == null ? true : false,
              _operation == '' ? val : _operation,
            ).toString();
          }
          //_operation = '';
          _temp1 = res;
          _temp2 = '0';
          _operation = val;
          calback(res.toString());
        }
      } else {
        if (_initItem && _temp1 == initVal && _operation == '') {
          _temp1 = '0';
          _initItem = false;
        }
        if (_operation == '') {
          _temp1 = _temp1 != '0' ? _temp1 + val : val;
          calback(_temp1.toString());
        } else {
          _temp2 = _temp2 != '0' ? _temp2.toString() + val : val;
          calback(_temp2.toString());
        }
      }

      // if (val == '٪') {
      // } else if (val == '÷') {
      // } else if (val == '×') {
      // } else if (val == '+') {
      // } else if (val == '-') {
      // } else if (val == '=') {
      //   if (_operation != '') {
      //     _temp = _calculate(val, _temp, _operation);
      //     _operation = '';
      //   }
      // } else {
      //   if (_temp == 0) {
      //     _temp = int.parse(_temp.toString() + val);
      //     return calback(_temp.toString());
      //   }
      // }
      // calback(val);
    },
    child: Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bgcolor,
      ),
      child: Text(
        val,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color:
              color ??
              (darkMode.value ? Colors.grey.shade200 : Colors.grey.shade900),
        ),
      ),
    ),
  );
}

_calculate(num one, num two, bool oneMinuse, bool twoMinnus, opt) {
  num? a;
  if (opt == '٪') {
  } else if (opt == '÷') {
    a = (one / two);
  } else if (opt == '×') {
    a = (one * two);
  } else if (opt == '+') {
    a = (one + two);
  } else if (opt == '-') {
    a = (one - two);
  }
  return a != null ? a.toStringAsFixed(0) : '0';
}
