import 'package:mik_router/mik_router.dart' as nav_routes;
// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_utils/public/POS/pos.dart';
import 'package:mik_utils/public/findID.dart';


// import 'package:pegahsystem/common/components/Toast.dart';
// import 'package:pegahsystem/common/components/pos/page.dart';
// // import 'package:pegahsystem/common/utils/posDetect.dart';
// import 'package:pegahsystem/service/api/order.dart';
// import 'package:pegahsystem/service/remote_status_code.dart';

class PosEvents {
  ///i9000s
  static const String startPayment_PNA = 'startPayment_PNA'; // پرداخت نوین
  static const String printI9000S = 'print_i9000s';

  ///p10
  static const String startPayment_SEP = 'startPayment_SEP'; // سپ
  static const String startPayment_BPM = 'startPayment_BPM'; // به پرداخت ملت
  static const String printP10 = 'print_p10';
}

final posPringGridKey = GlobalKey();

class MikYarPOS {
  static const posChannel = MethodChannel('com.rahkarapp.mikyar/POS');

  static Future pay(int amount) async {
    if (amount < 10000) {
      Alert.error('مبلغ پرداخت کمتر از 1,000 تومان است');
      return;
    }

    if (amount > 2000000000) {
      Alert.error('مبلغ پرداخت بیشتر از 200,000,000 تومان است');
      return;
    }

    try {
      var res;
      if (POSFX.brandPOS() == PosBrand.PNA) {
        Map<String, String> paymentData = {
          "AndroidPosMessageHeader": "@@PNA@@",
          "ECRType": "1",
          "Amount": "$amount",
          "TransactionType": "00"
        };
        res = await posChannel.invokeMethod(PosEvents.startPayment_PNA, {
          'json': paymentData,
        });
      } else if (POSFX.brandPOS() == PosBrand.SEP) {
//        Map<String, dynamic> paymentData = {
//   "versionName": "1.0.0",
//   "sessionId": "session_${DateTime.now().millisecondsSinceEpoch}",
//   "applicationId": 1000, // از به‌پرداخت می‌گیری
//   "totalAmount": "$amount",
//   "transactionType": "PURCHASE",
//   "printPaymentDetails": false
// };
//          res = await pnaChannel.invokeMethod(PosEvents.startPayment_SEP, {
//           'json': paymentData,
//         });

        Map<String, dynamic> paymentData = {
          "amount": "$amount",
          // در صورت نیاز:
          // "payId": "123456",
          // "billId": "654321",
        };

        res = await posChannel.invokeMethod(
          PosEvents.startPayment_SEP,
          {'json': paymentData},
        );
      } else if (POSFX.brandPOS() == PosBrand.BPM) {
        String id = ID.uidNew();
        Map<String, dynamic> paymentData = {
          "versionName": "2.0.0",
          "sessionId": id,
          "applicationId": 10145, // از به‌پرداخت
          "amount": amount.toString(), // مبلغ به ریال
          "transactionType": "PURCHASE",
          // اختیاری:
          // "payerId": "1234567890",
          // "echoData": "any-trace-id"
        };

        res = await posChannel.invokeMethod(
          PosEvents.startPayment_BPM,
          {'json': paymentData},
        );
        log('===================');
        log(res.toString());
        log('===================');
      } else {
        // Toast.error('این دستگاه پشتیبانی نمیشود');
      }
      //if (res != null) {
      // handlePay(res, POSFX.modelPOS());
      return res ?? {};
      //}
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("Failed to send intent: '${e.message}'.");
      }
      return {};
    }
  }

  static Future printInvoice(context,
      {required InvoiceDB factorData,
      required double paid,
      startPayment}) async {
    // order['MasterStatus'] == 'عادي'
    //   ? order['PreOrderMId']
    //   : order['OkPreOrderMId']);
    return MyBottomSheet.view(context,
        child: (d) => Column(
              children: [
                Text('فاکتور چاپ شود؟'),
                Row(
                  children: [
                    Flexible(
                      child: BTN(
                          onTap: () async {
                            await Get.toNamed(
                      nav_routes.RoutesName.INVOICE_PRINT,
                      arguments: {'data': factorData, 'paid': paid},
                      preventDuplicates: false,
                    );
                            Get.back();
                          },
                          icon: IconsaxPlusLinear.printer,
                          name: 'چاپ'),
                    ),
                    Flexible(
                        child: BTN(
                            onTap: () {
                              Get.back();
                            },
                            type: BTNType.cancel,
                            name: 'خیر'))
                  ],
                )
              ],
            ),
        initialChildSize: 110,
        title: '');

    // Get.to(CreateWidgetPring(
    //   data: factorData,
    //   paid: paid,
    // ));

    // ByteData byteData = await rootBundle.load('assets/images/12.jpg');
    // Uint8List? bytes; //= byteData.buffer.asUint8List();
    // List<int> bytes = await PosPrintInvoice.generate(
    //     {'customer': cm, 'order': order, 'items': orderItem});

    // if (bytes == null) {
    //   Toast.error('خطا در دریافت تصویر');
    //   return;
    // }
    // String base64Image = base64Encode(Uint8List.fromList(bytes!));
    // try {
    //   if (PosDetect.detect() == PosModel.i9000S) {
    //     final res =
    //         await pnaChannel.invokeMethod('print', {'image': base64Image});
    //     print('Result: $res');
    //   } else {
    //     Toast.error('این دستگاه پشتیبانی نمیشود');
    //   }
    // } catch (e) {
    //   print('Print error: $e');
    // }
  }

  static getMetaData(response) async {
    // Map metaData = {};
    try {
      switch (POSFX.brandPOS()) {
        case PosBrand.BPM:
          late var res;
          if (kDebugMode) {
            res = response;
          } else {
            res = jsonDecode(response);
          }
          print('res is 2 : $response');
          return {
            'terminalID': res['terminalID'], // شماره ترمینال
            'responseTime': res['responseTime'], // زمان پاسخ
            'responseDate': res['responseDate'], // تاریخ پاسخ
            'maskedCardNumber': res['maskedCardNumber'], //شماره کارت
            'referenceID': res['referenceID'], // شماره مرجع
            'trackingID': res['trackingID'], // شماره رهگیری
            'amount': res['amount'], // قیمت
       'sessionId' : res['sessionId'], // شناسه تراکنش
       'retrievalReferencedNumber': res['retrievalReferencedNumber'] // شماره پیگیری اعلام شده از سمت مرکز
          };
        // {"amount":"10000","responseDescription":"تراکنش موفق","responseTime":"162223","retrievalReferencedNumber":1,"sessionId":"83138bf9-f200-5ca4-b29e-5bae4e9380da","terminalID":"نسخه تستی","versionName":"2.0.0","maskedCardNumber":"502229******4503","referenceID":"790763222017","responseDate":"260225","responseCode":"000"}
        // return metaData;
      }
    } catch (e) {
      print('get metadata error $e');
    }
  }
}
