import 'dart:developer';

import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_update/flutter_app_update.dart';
import 'package:flutter_app_update/result_model.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/source/remote/api.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../base/error.dart';

// import 'package:r_upgrade/r_upgrade.dart';

class UpgradePage extends GetView {
  UpgradePage({super.key});
  RxBool upgrade = false.obs, instalWait = false.obs;
  RxDouble percent = 0.0.obs, planTime = 0.0.obs, speed = 0.0.obs;
  RxInt maxLength = 0.obs, currentLength = 0.obs;
  RxBool load = false.obs;
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => load.isFalse || load.isTrue
          ? Main(
              initState: () async => await init(),
              header: Header.page(context, text: 'بروزرسانی'),
              loadingDuration: 2000,
              child: (d) => d == '' || d == null
                  ? ErrorPage(
                      'خطا در ارتباط با سرور...',
                      onTap: () async {
                        load.value = true;
                        d = await init();

                        load.value = false;
                      },
                    )
                  : checkVersion(d)
                  ? EmptyList(
                      icon: IconsaxPlusLinear.tick_circle,
                      emoji: '🥳',
                      text: 'از آخرین نسخه «میک» استفاده می‌کنید.',
                    )
                  : Obx(
                      () => upgrade.isFalse
                          ? Column(
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  'نسخه جدیدی از نرم افزار منتشر شده است.\nنسخه شما:$version  >>  نسخه جدید: ${Platform.isAndroid ? d['versionAndroid'] : d['versionIOS']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 20),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < d['change'].split('\n').length;
                                          i++
                                        )
                                          d['change']
                                                  .split('\n')[i]
                                                  .toString()
                                                  .startsWith('تغییرات نسخه')
                                              ? Container(
                                                  //  width: Get.width - 92,
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        flex: 3,
                                                        child: Container(
                                                          height: 1,
                                                          margin:
                                                              const EdgeInsets.only(
                                                                left: 10,
                                                              ),
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                      Flexible(
                                                        flex: 4,
                                                        child: Text(
                                                          d['change'].split(
                                                            '\n',
                                                          )[i],
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                      Flexible(
                                                        flex: 3,
                                                        child: Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                right: 10,
                                                              ),
                                                          height: 1,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 10,
                                                        left: 10,
                                                      ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Icon(
                                                        IconsaxPlusLinear
                                                            .info_circle,
                                                        color:
                                                            AppColors.secondary,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Flexible(
                                                        child: Text(
                                                          d['change'].split(
                                                            '\n',
                                                          )[i],
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 15,
                                                              ),
                                                          softWrap: true,
                                                          textWidthBasis:
                                                              TextWidthBasis
                                                                  .longestLine,
                                                          maxLines: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.only(
                                    right: 10,
                                    left: 10,
                                    bottom: 15,
                                  ),
                                  child: BTN(
                                    onTap: () async {
                                      // if (await canLaunchUrlString(d['link'])) {
                                      //   launchUrlString(d['link']);
                                      // } else {
                                      //   Alert.error(
                                      //       'عدم امکان دانلود نسخه جدید!');
                                      // }
                                      await Permission.storage.request();
                                      await Permission.manageExternalStorage
                                          .request();
                                      var b = await canLaunchUrlString(
                                        d['link'],
                                      );
                                      // if (b) {
                                      percent.value = 0.0;
                                      // planTime = 0.0.obs, speed = 0.0.obs;
                                      maxLength.value = 0;
                                      currentLength.value = 0;

                                      UpdateModel model = UpdateModel(
                                        d['link'],
                                        'MiK-V${d['version']}.apk',
                                        'ic_launcher',
                                        '',
                                      );
                                      upgrade.value = true;

                                      await AzhonAppUpdate.update(model)
                                          .then((value) {
                                            log("DONE!");
                                          });
                                      // }
                                      // await RUpgrade.upgrade(d['link'],
                                      //     fileName:
                                      //         'NewMIK-V${d['versionAndroid']}.apk',
                                      //     // header: {
                                      //     //   'Downloading':
                                      //     //       'در حال دانلود نسخه ${d['versionAndroid']} «میک» '
                                      //     // },
                                      //     // isAutoRequestInstall: true,
                                      //     upgradeFlavor:
                                      //         RUpgradeFlavor.hotUpgrade,
                                      //     notificationStyle: NotificationStyle
                                      //         .speechAndPlanTime,
                                      //     notificationVisibility:
                                      //         NotificationVisibility
                                      //             .VISIBILITY_VISIBLE,
                                      //     // upgradeFlavor: RUpgradeFlavor.incrementUpgrade,
                                      //     useDownloadManager: true);

                                      // RUpgrade.stream
                                      //     .listen((DownloadInfo info) {
                                      //   log(info.toString());
                                      //   upgrade.value = true;
                                      //   percent.value = info.percent!;
                                      //   planTime.value = info.planTime!;
                                      //   speed.value = info.speed!;
                                      //   maxLength.value = info.maxLength!;
                                      //   currentLength.value =
                                      //       info.currentLength!;
                                      //   if (info.percent == 100) {
                                      //     upgrade.value = false;
                                      //   }
                                      // });
                                    },
                                    name: 'دانلود نسخه جدید',
                                  ),
                                ),
                              ],
                            )
                          : instalWait.isFalse
                          ? Container(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  SizedBox(height: Get.height / 4),
                                  Icon(
                                    IconsaxPlusLinear.import,
                                    size: 100,
                                    color: Colors.black.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 30),
                                  Container(
                                    alignment: Alignment.center,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: const Text(
                                      'لطفا منتظر بمانید....',
                                      style: TextStyle(fontSize: 17),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 30,
                                    child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Obx(
                                          () => LinearProgressIndicator(
                                            backgroundColor:
                                                AppColors.boxBackground,
                                            color: AppColors.primary,
                                            value: percent.value,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        alignment: Alignment.bottomRight,
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                          right: 8,
                                          left: 8,
                                        ),
                                        child: Obx(
                                          () => Text(
                                            '${(maxLength.value / (1024 * 1024)).toStringAsFixed(1)}Mb',
                                          ),
                                        ),
                                      ),
                                      Obx(
                                        () => Text(
                                          '${(percent.value * 100).toStringAsFixed(0)}%',
                                          // style: TextStyle(fontSize: width / 30, color: dotColor),
                                        ),
                                      ),
                                      Container(
                                        alignment: Alignment.bottomRight,
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                          right: 8,
                                          left: 8,
                                        ),
                                        child: Obx(
                                          () => Text(
                                            '${(currentLength.value / (1024 * 1024)).toStringAsFixed(1)}Mb',
                                          ),
                                        ),
                                      ),
                                      // Container(
                                      //     alignment: Alignment.bottomRight,
                                      //     margin: const EdgeInsets.only(
                                      //         bottom: 20, right: 8, left: 8),
                                      //     child: Obx(() => Text(
                                      //           speed.value > 1000
                                      //               ? 'سرعت دانلود: ${(speed.value / 1024).toStringAsFixed(1)}Mb/s'
                                      //               : 'سرعت دانلود: ${(speed.value).toStringAsFixed(1)}Kb/s',
                                      //         ))),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                SizedBox(height: Get.height / 4),
                                Icon(
                                  IconsaxPlusLinear.timer,
                                  size: 100,
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 30),
                                Container(
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: const Text(
                                    'در انتظار نصب...',
                                    style: TextStyle(fontSize: 17),
                                  ),
                                ),
                              ],
                            ),
                    ),
            )
          : Container(),
    );
  }

  init() async {
    AzhonAppUpdate.listener((ResultModel event) {
      percent.value = (event.progress ?? 0) / (event.max ?? 1);
      maxLength.value = event.max ?? 1;
      currentLength.value = event.progress ?? 0;
      if (currentLength.value == maxLength.value) {
        instalWait.value = true;
        Alert.success('دانلود نسخه جدید با موفقیت انجام شد');
      }
    });
    var d = await API.checkStatus();
    d['change'] = '';
    return d;
  }

  checkVersion(ver) {
    if (ver != 400) {
      int v = int.parse(
        (Platform.isAndroid
                ? ver['versionAndroid'].toString()
                : ver['versionIOS'].toString())
            .replaceAll('.', ''),
      );
      return v < int.parse(version.replaceAll('.', ''));
    }
    return true;
  }
}
