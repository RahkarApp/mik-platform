// ignore_for_file: file_names, prefer_if_null_operators

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MyBottomSheet {
  static view(
    context, {
    required Widget Function(ScrollController scrollController) child,
    required String title,
    Widget? titleWidget,
    double? initialChildSize,
    bool? isScrollControlled,
    bool showClose = true,
    bool isDismissible = true,
    List<Widget>? actions,
    double? height,
    double? width,
  }) {
    // if (Responsive.isDesktop(context) ||
    //     Responsive.isDesktopLarg(context) ||
    //     Responsive.isTablet(context)) {
    //   _buildDesktopDialog(
    //     context,
    //     title: title,
    //     child: child(ScrollController()),
    //     actions: actions,
    //     height: height,
    //     width: width,
    //   );
    //   return;
    // }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: isScrollControlled ?? true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      // useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        // اگر initialChildSize یا fitSize مشخص شده باشد، مانند قبل رفتار DraggableScrollableSheet دارد.
        if (initialChildSize != null) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: (initialChildSize > 0.95
                    ? 0.95
                    : initialChildSize),
                minChildSize: (initialChildSize < 0.3 ? initialChildSize : 0.3),
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      Container(
                        padding: EdgeInsets.only(right: 10),
                        // height: 40,
                        child: Row(
                          mainAxisAlignment:
                              showClose || (!showClose && actions != null)
                              ? MainAxisAlignment.spaceBetween
                              : MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: titleWidget == null
                                  ? MyTextScroll(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : titleWidget,
                            ),
                            SizedBox(width: 10),
                            Row(
                              children: [
                                if (actions != null) ...actions,
                                if (showClose)
                                  IconButton(
                                    icon: const Icon(
                                      IconsaxPlusLinear.close_circle,
                                    ),
                                    onPressed: () => Get.back(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(color: AppColors.disable),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsGeometry.symmetric(horizontal: 5),
                          child: child(scrollController),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }

        // در صورت عدم تعیین initialChildSize/fitSize به اندازه محتوا باز می‌شود
        // و در صورت زیاد بودن محتوا، داخل آن اسکرول فعال است.
        final scrollController = ScrollController();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = constraints.maxHeight * 0.9;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(right: 10),
                        //  height: 40,
                        child: Row(
                          mainAxisAlignment:
                              showClose || (!showClose && actions != null)
                              ? MainAxisAlignment.spaceBetween
                              : MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: titleWidget == null
                                  ? MyTextScroll(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : titleWidget,
                            ),
                            SizedBox(width: 10),
                            Row(
                              children: [
                                if (actions != null) ...actions,
                                if (showClose)
                                  IconButton(
                                    icon: const Icon(
                                      IconsaxPlusLinear.close_circle,
                                    ),
                                    onPressed: () => Get.back(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(color: AppColors.disable),
                      Flexible(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 5,
                          ),
                          child: child(scrollController),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // static view(Widget child, {ScrollController? scrollController, String header = '', double h = 400, bool isDismissible = true, bool showClose = true, padding}) {
  //   h = (h > (Get.height * 0.85) ? (Get.height * 0.85) : h);

  //   Get.bottomSheet(
  //       Obx(() => Container(
  //           // height: h,
  //           width: Get.width,
  //           constraints: BoxConstraints(maxHeight: Get.height - 100, minHeight: 100),
  //           padding: padding ?? const EdgeInsets.all(10),
  //           decoration: BoxDecoration(color: darkMode.value ? Colors.grey.shade800 : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10))),
  //           child: Column(mainAxisSize: MainAxisSize.min, children: [
  //             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
  //               Flexible(child: Container()),
  //               Flexible(
  //                   child: Container(
  //                 margin: const EdgeInsets.all(5),
  //                 height: 5,
  //                 decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey),
  //               )),
  //               Flexible(
  //                   child: isDismissible && showClose
  //                       ? InkWell(
  //                           onTap: () => Get.back(),
  //                           child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
  //                             Icon(
  //                               IconsaxPlusLinear.close_circle,
  //                               size: 20,
  //                               color: Colors.grey,
  //                             ),
  //                             SizedBox(width: 5),
  //                             Text(
  //                               'بستن',
  //                               style: TextStyle(color: Colors.grey),
  //                             )
  //                           ]))
  //                       : Container())
  //             ]),
  //             if (header != '')
  //               Container(
  //                 alignment: Alignment.center,
  //                 child: Text(
  //                   header,
  //                   textAlign: TextAlign.center,
  //                   maxLines: 2,
  //                   style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
  //                 ),
  //               ),
  //             if (header != '') const SizedBox(height: 10),
  //             SizedBox(height: h, child: SingleChildScrollView(controller: scrollController, child: darkMode.isFalse ? child : child))
  //           ]))),
  //       isScrollControlled: true,
  //       isDismissible: isDismissible,
  //       enableDrag: false);
  // }

  static viewAsync(
    Widget child, {
    String header = '',
    double h = 400,
    bool isDismissible = true,
  }) async {
    h = (h > (Get.height * 0.85) ? (Get.height * 0.85) : h);
    await Get.bottomSheet(
      Container(
        height: h,
        width: Get.width,
        constraints: BoxConstraints(maxHeight: Get.height - 100, minHeight: h),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: darkMode.value ? Colors.grey.shade800 : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Container()),
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey,
                    ),
                  ),
                ),
                Flexible(
                  child: isDismissible
                      ? InkWell(
                          onTap: () => Get.back(),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                IconsaxPlusLinear.close_circle,
                                size: 20,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'بستن',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : Container(),
                ),
              ],
            ),
            if (header != '')
              Container(
                alignment: Alignment.center,
                child: Text(
                  header,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (header != '') const SizedBox(height: 10),
            Expanded(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: false,
    );
  }

  static viewSupports(
    context, {
    bool? isScrollControlled,
    List<Widget>? actions,
  }) {
    view(context, child: (d) => _buildSupport(), title: 'پشتیبانی');
    // showModalBottomSheet(
    //   context: context,
    //   isScrollControlled: isScrollControlled ?? true,
    //   shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    //   builder: (context) {
    //     return Padding(
    //       padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    //       child: DraggableScrollableSheet(
    //         expand: false,
    //         initialChildSize: 0.17,
    //         minChildSize: 0.1,
    //         builder: (context, scrollController) {
    //           return Column(children: [Expanded(child: _buildSupport())]);
    //         },
    //       ),
    //     );
    //   },
    // );
  }

  static void _buildDesktopDialog(
    BuildContext context, {
    required String title,
    required Widget child,
    List<Widget>? actions,
    double? height,
    double? width,
  }) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Row(
                children: [
                  if (actions != null) ...actions,
                  IconButton(
                    icon: const Icon(IconsaxPlusLinear.close_circle),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                // color: AppColors.orange,
                width: width ?? 400,
                height: height ?? 400,
                child: Center(child: child),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildSupport() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSendMenuItem('tell', 'تماس', () async {
            await launchUrlString('tel://03191011023');
          }),

          _buildSendMenuItem('telegram', 'تلگرام', () async {
            await launchUrlString(
              'tg:resolve?domain=MiK_Support',
              mode: LaunchMode.externalApplication,
            );
          }),
          _buildSendMenuItem('whatsapp', 'واتس‌آپ', () async {
            await launchUrlString(
              'https://wa.me/983191011023',
              mode: LaunchMode.externalApplication,
            );
          }, size: 60),
          // Padding(
          //   padding: const EdgeInsets.only(left: 7.0),
          //   child: _buildSendMenuItem('eitaa', 'ایتا', () async {
          //     await launchUrlString("https://eitaa.com/MiK_Support", mode: LaunchMode.externalApplication);
          //   }),
          // ),
        ],
      ),
    );
  }

  static InkWell _buildSendMenuItem(
    String imageName,
    String name,
    dynamic onTap, {
    double size = 50,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    child: Column(
      spacing: 5,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: size + 2,
          width: size + 2,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/icon/$imageName-icon.png',
            width: size,
            height: size,
          ),
        ),
        Text(name),
      ],
    ),
  );
}
