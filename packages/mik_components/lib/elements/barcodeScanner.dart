// import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
// import 'package:flutter_beep/flutter_beep.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import 'package:mik_consts/colors.dart';

RxBool _isTorchOn = false.obs;
BarcodeViewController _controller = BarcodeViewController.data(1);
// final MobileScannerController _ctl = MobileScannerController();
barcodeScaner() async {
  var status = await Permission.camera.status;
  if (status.isDenied) {
    await Permission.camera.request();
  }

  //this Dialog is OK
  return Get.dialog(
    Scaffold(
      backgroundColor: Colors.black12,
      body: Container(
        alignment: Alignment.topCenter,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10)),
        ),
        child: Column(children: [_buildBarcodeScannerBody(), _bottomSide()]),
      ),
    ),
  );
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
          onPressed: () => {Get.back(result: '')},
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

Widget _buildBarcodeScannerBody() {
  return SizedBox(
    height: Get.width,
    child:
        // AiBarcodeScanner(
        //   controller: _ctl,
        //   onScan: (String value) {
        //     debugPrint(value);
        //     Get.back(result: value);
        //   },
        // ),
        SimpleBarcodeScanner(
          scaleHeight: 200,
          scaleWidth: 400,
          continuous: true,
          onScanned: (data) {
            // FlutterBeep.beep();
            Get.back(result: data);
          },
          onBarcodeViewCreated: (BarcodeViewController controller) {
            _controller = controller;
          },
        ),
  );
}
