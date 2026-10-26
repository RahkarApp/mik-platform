// ignore_for_file: must_be_immutable, unused_field

import 'package:flutter/material.dart';
import 'package:flutter_onboarding_slider/flutter_onboarding_slider.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_consts/colors.dart';

class OnboardingScreen extends GetView {
  OnboardingScreen({super.key});
  late PageController _pageController = PageController(initialPage: 0);
  List<OnboardingPageModel> pages = [
    OnboardingPageModel(
      title: 'به میک خوش آمدید',
      description: 'میک، یک دستیار تمام عیار برای کسب و کار توست.\nما اینجاییم تا به تو کمک کنیم سرعت و دقت کسب و کارت رو بالاتر ببری و مشتریانت بیش از پیش از کسب و کار تو حس خوب بگیرند.',
      image: 'packages/mik_pages/assets/images/onboard/IMG_2894.png',
      bgColor: darkMode.isFalse
          ? AppColors.background
          : AppColors.backgroundDarkMode,
      textColor: darkMode.isTrue
          ? AppColors.background
          : AppColors.backgroundDarkMode,
    ),
    OnboardingPageModel(
      title: 'مدیریت همه جانبه',
      description: 'میک به شما کمک میکنه همه چیز رو مدیریت کنید!\nاز سفارشات و موجودی محصولات گرفته تا مشتریان و تامین‌کنندگان و همه حساب‌کتاب‌ها...',
      image: 'packages/mik_pages/assets/images/onboard/IMG_2908.png',
      bgColor: darkMode.isFalse
          ? AppColors.background
          : AppColors.backgroundDarkMode,
      textColor: darkMode.isTrue
          ? AppColors.background
          : AppColors.backgroundDarkMode,
    ),
    OnboardingPageModel(
      title: 'مشتری در جریانه',
      description: 'با میک، مشتری شما همیشه در جریان آخرین وضعیت سفارش خودش هست و حالا مشتری حس بهتری داره.\nمثل حرفه‌ای‌ها میک برای مشتری شما پیامک ارسال میکنه و مشتری رو در جریان میذاره.',
      image: 'packages/mik_pages/assets/images/onboard/IMG_2890.png',
      bgColor: darkMode.isFalse
          ? AppColors.background
          : AppColors.backgroundDarkMode,
      textColor: darkMode.isTrue
          ? AppColors.background
          : AppColors.backgroundDarkMode,
    ),
    OnboardingPageModel(
      title: 'خیالت بابت پرداخت راحته',
      description: 'دیگه از رسید جعلی خبری نیست!\nبا استفاده از کیف پول و سیستم پرداخت آنلاین میک، از این پس مشتریان شما هزینه سفارش رو آنلاین پرداخت میکنن و شما همیشه خیالت راحته!',
      image: 'packages/mik_pages/assets/images/onboard/IMG_2905.png',
      bgColor: darkMode.isFalse
          ? AppColors.background
          : AppColors.backgroundDarkMode,
      textColor: darkMode.isTrue
          ? AppColors.background
          : AppColors.backgroundDarkMode,
    ),
    OnboardingPageModel(
      title: 'سفارش‌گیری همیشه و هرجا',
      description: 'بجز اینکه همیشه و هر جا انبار محصولاتت توی دستت هست و میتونی سفارش ثبت کنی، میک برای کسب و کارت یک فروشگاه آنلاین میسازه تا مشتریان شما کاملا آنلاین سفارش خودشون رو ثبت و پرداخت کنند.',
      image: 'packages/mik_pages/assets/images/onboard/IMG_2941.png',
      bgColor: darkMode.isFalse
          ? AppColors.background
          : AppColors.backgroundDarkMode,
      textColor: darkMode.isTrue
          ? AppColors.background
          : AppColors.backgroundDarkMode,
    ),
    OnboardingPageModel(
      title: 'همه چیز آمادست',
      description: 'با میک همه چیز برای مدیریت هرچه بهتر کسب و کارت آمادست!\nبزن بریم...',
      end: true,
      image: 'packages/mik_pages/assets/images/onboard/IMG_2912.png',
      bgColor: darkMode.isFalse
          ? AppColors.background
          : AppColors.backgroundDarkMode,
      textColor: darkMode.isTrue
          ? AppColors.background
          : AppColors.backgroundDarkMode,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    RxInt currentPage = 0.obs;
    _pageController = PageController(initialPage: 0);
    return Material(
      child: SafeArea(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: OnBoardingSlider(
            controllerColor: AppColors.primary.withValues(alpha: 0.3),
            totalPage: pages.length,

            //middle: Text('data'),
            onFinish: () {
              Get.offAllNamed(RoutesName.LOGIN);
            },
            finishButtonStyle: FinishButtonStyle(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
              ),
              backgroundColor: AppColors.primary,
              elevation: 0,
            ),
            centerBackground: true,
            skipFunctionOverride: () => MyBottomSheet.viewSupports(context),
            skipTextButton: Text(
              'نیاز به پشتیبانی دارید؟',
              style: TextStyle(
                color: darkMode.isTrue
                    ? AppColors.background
                    : AppColors.backgroundDarkMode,
                fontSize: 12,
              ),
            ),
            finishButtonTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
            finishButtonText: 'ورود / عضویت',
            background: pages
                .map(
                  (e) => SizedBox(
                    height: Get.height,
                    child: Column(
                      children: [
                        SizedBox(height: 30),
                        Expanded(child: Image.asset(e.image)),
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Text(
                            e.title,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: e.textColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: Get.width * 0.8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 8.0,
                              ),
                              child: Text(
                                pages[currentPage.value].description,
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: e.textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            speed: 1,
            headerBackgroundColor: darkMode.isFalse
                ? AppColors.background
                : AppColors.backgroundDarkMode,
            pageBodies: pages.map((e) => Text('')).toList(),
          ),
        ),
      ),
    );
  }
}

class OnboardingPageModel {
  final String title;
  final String description;
  final String image;
  final Color bgColor;
  final Color textColor;
  final bool end;
  OnboardingPageModel({
    required this.title,
    required this.description,
    required this.image,
    this.bgColor = Colors.blue,
    this.textColor = Colors.white,
    this.end = false,
  });
}
