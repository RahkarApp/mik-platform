// ignore_for_file: empty_catches, unused_element

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_variables/variable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scan/scan.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:universal_io/io.dart';

import 'package:mik_consts/colors.dart';

RxBool _isTorchOn = false.obs;
ScanController _controller = ScanController();

class Scanner {
  // final MobileScannerController _ctl = MobileScannerController();
  static barcode(context) async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      await Permission.camera.request();
    }
    String barcode = '';
    if (kIsWeb) {
      String? res = await SimpleBarcodeScanner.scanBarcode(
        context,
        barcodeAppBar: BarcodeAppBar(
          backButtonIcon: Icon(
            IconsaxPlusLinear.arrow_right_3,
            color: AppColors.primary,
          ),
          enableBackButton: true,
        ),
        isShowFlashIcon: true,
        delayMillis: 2000,

        cameraFace: CameraFace.front,
        lineColor: AppColors.primary.toString(),
      );
      barcode = res ?? '';
    } else {
      await Get.dialog(
        Scaffold(
          backgroundColor: Colors.black12,
          body: SafeArea(
            child: Container(
              alignment: Alignment.topCenter,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: Column(
                children: [
                  _buildBarcodeScannerBody((code) {
                    barcode = code;
                    Get.back();
                  }),
                  _bottomSide(),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return barcode;
  }
}

_bottomSide() {
  return Container(
    height: 55,
    decoration: BoxDecoration(
      color: Colors.grey[850],
      border: Border(top: BorderSide(color: AppColors.primary, width: 3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => {Get.back()},
          icon: const Icon(Icons.cancel, color: Colors.white),
        ),
        const Text(
          'اسکن بارکد',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Obx(
          () => IconButton(
            onPressed: () async {
              try {
                // _controller.toggleTorchMode();
                // _ctl.toggleTorch();
                _isTorchOn.toggle();
              } catch (e) {}
            },
            icon: Icon(
              _isTorchOn.isTrue ? Icons.flashlight_off : Icons.flashlight_on,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildBarcodeScannerBody(callback) {
  return SizedBox(
    height: isMobile.value ? Get.width : Get.height / 2,
    // child:
    // AiBarcodeScanner(
    //   controller: _ctl,
    //   onScan: (String value) {
    //     debugPrint(value);
    //     Get.back(result: value);
    //   },
    // ),

    child: ScanView(
      controller: _controller,
      scanAreaScale: 0.9,
      scanLineColor: AppColors.primary,
      onCapture: (data) {
        // FlutterBeep.beep();

        callback(data);
      },
    ),
  );
}
