import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/main/mobile.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_variables/variable.dart';

import 'package:url_launcher/url_launcher.dart';

class DeactiveScreen extends GetView {
  const DeactiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainMobile(
      initState: () async => {},
      child: (data) => Container(
        margin: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 30,
          children: [
            Icon(
              IconsaxPlusLinear.slash,
              size: 90,
              color: darkMode.isFalse ? Colors.black45 : Colors.white54,
            ),
            Flexible(
              child: Text(
                'سلام دوست عزیز \nمتاسفانه نرم افزار شما غیر غعال شده است.\nبرای اطلاع از علت این خطا، لطفا با پشتیبانی تماس بگیرید.\nکد کاربری شما: ${profile.getAt(0)!.id}',
                style: TextStyle(fontSize: 18, height: 2),
                textAlign: TextAlign.justify,
              ),
            ),
            BTN(
              onTap: () {
                var uri = Uri(scheme: 'tel', path: '03191011023');
                launchUrl(uri);
              },
              icon: IconsaxPlusLinear.call,
              name: 'تماس با پشتیبانی: ۰۳۱۹۱۶۹۰۶۳۲',
            ),
          ],
        ),
      ),
    );
  }
}
