import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/main/mobile.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_variables/variable.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class DateErrorPage extends GetView {
  const DateErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MainMobile(
      initState: () async => '',
      child: (d) => Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            IconsaxPlusLinear.clock_1,
            size:
                Responsive.isDesktop(context) ||
                    Responsive.isDesktopLarg(context)
                ? 100
                : Get.width / 5,
            color: darkMode.isTrue ? Colors.white38 : Colors.black26,
          ),
          Text(
            'برای ادامه کار لطفا تاریخ و ساعت دستگاه را تنظیم کنید.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: darkMode.isTrue ? Colors.white38 : Colors.black45,
            ),
          ),
          if (DateTime.now().timeZoneOffset.inMinutes != 210)
            Text(
              'منطقه زمانی (Time Zone) شما صحیح نمی باشد.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: darkMode.isTrue ? Colors.white38 : Colors.black45,
              ),
            ),
          Text(
            'زمان دستگاه :',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: darkMode.isTrue ? Colors.white38 : Colors.black45,
            ),
          ),
          Text(
            'زمان صحیح :',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: darkMode.isTrue ? Colors.white38 : Colors.black45,
            ),
          ),
          SizedBox(height: 30),
          BTN(
            borderOnly: true,
            margin: Responsive.isMobile(context) || Responsive.isTablet(context)
                ? null
                : EdgeInsets.symmetric(
                    horizontal: Responsive.getWidth(context) / 3,
                  ),
            onTap: () async {
              if (Platform.isAndroid) {
                const url = 'android.settings.DATE_SETTINGS';
                if (await canLaunchUrl(
                  Uri.parse(
                    'intent://$url#Intent;action=android.intent.action.VIEW;category=android.intent.category.DEFAULT;end',
                  ),
                )) {
                  await launchUrl(
                    Uri.parse(
                      'intent://$url#Intent;action=android.intent.action.VIEW;category=android.intent.category.DEFAULT;end',
                    ),
                  );
                } else {
                  throw 'Could not open date and time settings';
                }
              } else if (Platform.isIOS) {
                const url = 'App-Prefs:root=General';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  throw 'Could not open settings';
                }
              } else if (Platform.isWindows) {
                var url = 'ms-settings:dateandtime';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  throw 'Could not launch $url';
                }
              } else if (kIsWeb) {
                const url =
                    'https://www.wikihow.com/Change-the-Date-and-Time-on-a-Computer';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  throw 'Could not open the settings page';
                }
              }
            },
            name: 'رفتن به تنظیمات',
            icon: IconsaxPlusLinear.setting_2,
          ),
          BTN(
            icon: IconsaxPlusLinear.tick_circle,
            margin: Responsive.isMobile(context) || Responsive.isTablet(context)
                ? null
                : EdgeInsets.symmetric(
                    horizontal: Responsive.getWidth(context) / 3,
                  ),
            onTap: () async {
              Get.offAllNamed(RoutesName.SPLASH);
            },
            name: 'تنظیم کردم!',
          ),
        ],
      ),
    );
  }
}
