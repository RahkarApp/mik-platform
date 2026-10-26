import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_data/source/remote/sockets/socket.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/helpCenter/helpSheet.dart';
import 'package:shamsi_date/shamsi_date.dart';

class Header {
  static Widget dashboard() {
    return Obx(
      () => Material(
        elevation: 2,
        child: Container(
          height: 43,
          color: AppColors.background,
          // margin:
          //     const EdgeInsets.only(top: 25, left: 8, right: 5, bottom: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(IconsaxPlusLinear.menu, size: 25),
                  ),
                  const SizedBox(width: 8),
                  const Text('', style: TextStyle(fontSize: 18)),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {},
                    child: const Icon(IconsaxPlusLinear.notification, size: 25),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {},
                    child: const Icon(
                      IconsaxPlusLinear.messages_3,
                      size: 25,
                      weight: 1,
                      grade: 1,
                      opticalSize: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget page(
    context, {
    required String text,
    bool isBack = true,
    Widget? child,
    bool confirmBack = false,
    Function? onTapConfirm,
    String? confirmBackText,
    bool help = true,
  }) {
    return Material(
      elevation: 2,
      child: Obx(
        () => AnimatedContainer(
          duration: Duration(milliseconds: 500),
          // margin: EdgeInsets.only(top: statusBarHeight.value),
          height:
              serverConnect.value == 'fresh' || serverConnect.value == 'error'
              ? 67
              : 55,
          // padding: const EdgeInsets.only(top: 4),
          color: darkMode.isFalse
              ? AppColors.background
              : AppColors.backgroundDarkMode,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        context != null
                            ? Responsive.isMobile(context)
                                  ? backItem(
                                      context,
                                      confirmBack,
                                      onTapConfirm,
                                      confirmBackText,
                                    )
                                  : isBack
                                  ? backItem(
                                      context,
                                      confirmBack,
                                      onTapConfirm,
                                      confirmBackText,
                                    )
                                  : Container()
                            : backItem(
                                context,
                                confirmBack,
                                onTapConfirm,
                                confirmBackText,
                              ),
                        SizedBox(width: 15),
                        Flexible(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Obx(
                        () => internetCheck.isFalse
                            ? InkWell(
                                onTap: () => Alert.error(
                                  'دسترسی به اینترنت مقدور نیست!',
                                ),
                                child: Icon(
                                  IconsaxPlusLinear.wifi,
                                  color: AppColors.error,
                                ),
                              )
                            : Container(),
                      ),
                      const SizedBox(width: 15),
                      child ?? Container(),
                      // if (child != null) const SizedBox(width: 15),
                      if (help == true)
                        InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.only(left: 10),
                            child: InkWell(
                              onTap: () async {
                                await HelpPageSheet.view(context);
                              },
                              child: Icon(
                                IconsaxPlusLinear.message_question,
                                color: darkMode.isFalse
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (isMobile.value &&
                  (serverConnect.value == 'error' ||
                      serverConnect.value == 'fresh'))
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 500),
                          width: Get.width,
                          decoration: BoxDecoration(
                            color: serverConnect.value == 'error'
                                ? AppColors.error
                                : AppColors.success,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Center(
                              child: Text(
                                serverConnect.value == 'error' ||
                                        serverConnect.value == 'disconnect'
                                    ? 'اتصال به سرور قطع شد، درحال اتصال مجدد... '
                                    : 'متصل شد',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static InkWell backItem(
    context,
    bool confirmBack,
    Function? onTapConfirm,
    String? confirmBackText,
  ) {
    return InkWell(
      onTap: () => !confirmBack
          ? Get.rawRoute == null
                ? Get.offAllNamed(RoutesName.DASHBOARD)
                : Get.back()
          : {
              MyBottomSheet.view(
                context,
                child: (d) => Column(
                  children: [
                    BTN(
                      onTap: () async {
                        if (onTapConfirm != null) {
                          await onTapConfirm();
                          Get.back();
                        }
                      },
                      name: 'ذخیره و بازگشت',
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: BTN(
                            onTap: () async {
                              Get.back();
                              Get.back();
                            },
                            color: AppColors.error,
                            name: 'بازگشت بدون ذخیره',
                          ),
                        ),
                        Flexible(
                          child: BTN(
                            type: BTNType.cancel,
                            onTap: () => Get.back(),
                            name: 'انصراف',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                showClose: false,
                title: confirmBackText ?? 'تغییرات ذخیره نشده است!',
              ),
            },
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 50,
        width: 50,
        child: Icon(
          IconsaxPlusLinear.arrow_right_3,
          color: darkMode.isFalse ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

RxBool isOnTapChild = false.obs;

// ignore: must_be_immutable
class HeaderPagesDesktop extends StatelessWidget {
  String title;
  IconData? iconL;
  void Function()? onTap;
  Widget? child;
  HeaderPagesDesktop({
    required this.title,
    this.iconL,
    this.onTap,
    this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 30)),
              Row(
                children: [
                  child == null
                      ? Container()
                      : InkWell(
                          onTap: () {
                            showCustomDialog(
                              context,
                              child!, // ویجتی که می‌خواهید داخل دیالوگ نمایش داده شود
                            );
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: (darkMode.value
                                    ? AppColors.background
                                    : AppColors.backgroundDarkMode),
                              ),
                            ),
                            child: const Icon(
                              IconsaxPlusLinear.document_filter,
                            ),
                          ),
                        ),
                  Obx(
                    () => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: isOnTapChild.value ? 50 : 0,
                      width: isOnTapChild.value
                          ? Responsive.getWidth(context) / 3.2
                          : 0,
                      child: child,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: (darkMode.value
                            ? AppColors.background
                            : AppColors.backgroundDarkMode),
                      ),
                    ),
                    child: const Icon(Icons.question_mark),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Container(color: Colors.grey, height: 2),
        ),
      ],
    );
  }
}

class HeaderDesktop extends GetView {
  RxString now = Jalali.now().toString().obs;

  HeaderDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    init();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(),
          height: 60,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            color: AppColors.primary,
            // border: Border.all(color: Colors.white)
          ),
          child: Row(
            spacing: 10,
            children: [
              // SizedBox(width: 5,),
              Container(
                margin: EdgeInsets.only(right: 10),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Image.network(
                  'https://app.mikcore.ir/v2/img/profile/0/profile.png',
                  headers: {
                    "Content-Type": "application/json",
                    'auth-token': jwt
                        .getAt(mikyarProfileIndex)!
                        .token
                        .toString(),
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(IconsaxPlusLinear.profile),
                ),
              ),

              Text(
                '${profile.isEmpty ? '' : profile.getAt(0)?.name ?? ''}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Flexible(child: Container()),
              Obx(
                () => Icon(
                  IconsaxPlusLinear.wifi,
                  color: serverConnect.value == 'ok'
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              Obx(
                () => Text(
                  now.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 5),
            ],
          ),
        ),
        // AnimatedContainer(
        //   duration: Duration(milliseconds: 500),
        //   width: MediaQuery.of(context).size.width - 90,
        //   height: !isMobile.value &&
        //           (serverConnect.value == 'error' ||
        //               serverConnect.value == 'fresh')
        //       ? 20
        //       : 0,
        //   child: Row(
        //     children: [
        //       Flexible(
        //           child: AnimatedContainer(
        //         duration: Duration(milliseconds: 500),
        //         decoration: BoxDecoration(
        //             color: serverConnect.value == 'error'
        //                 ? AppColors.error
        //                 : AppColors.success),
        //         child: Padding(
        //           padding: const EdgeInsets.only(right: 20),
        //           child: Center(
        //               child: Text(
        //             serverConnect.value == 'error'||serverConnect.value == 'disconnect'
        //                 ? 'اتصال به سرور قطع شد، درحال اتصال مجدد... '
        //                 : 'متصل شد',
        //             style:
        //                 const TextStyle(color: Colors.white, fontSize: 12),
        //           )),
        //         ),
        //       ))
        //     ],
        //   ),
        // )
      ],
    );
  }

  init() {
    Jalali jDate = Jalali.now();

    now.value =
        '${jDate.hour}:${jDate.minute}:${jDate.second}  ${jDate.year}/${jDate.month}/${jDate.day}';
    Timer.periodic(Duration(seconds: 1), (v) {
      // var dateTime = DateTime.now();
      Jalali jDate = Jalali.now();

      now.value =
          '${jDate.hour}:${jDate.minute}:${jDate.second}  ${jDate.year}/${jDate.month}/${jDate.day}';
    });
  }
}

class CustomDialog extends StatelessWidget {
  final Widget child;

  const CustomDialog({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ), // Optional: for rounded corners
      child: SizedBox(
        width: MediaQuery.of(context).size.height / 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Get.back();
                  },
                ),
              ],
            ),
            Container(padding: const EdgeInsets.all(16.0), child: child),
          ],
        ),
      ),
    );
  }
}

void showCustomDialog(BuildContext context, Widget child) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return CustomDialog(child: child);
    },
  );
}
