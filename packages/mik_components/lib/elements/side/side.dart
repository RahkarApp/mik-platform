import 'package:mik_components/host.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_router/routing.dart';

import 'package:mik_consts/colors.dart';

import 'package:mik_components/elements/side/components/components.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/utils/variable.dart';

import 'package:universal_io/io.dart';

RxInt selectItem = 1.obs;

class Side extends GetView {
  const Side({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(Responsive.isDesktop(context) || Responsive.isDesktopLarg(context))) {
      if (selectItem.value != 0) selectItem.value = 0;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: Responsive.getHeight(context),
                width: 1,
                color: Colors.grey,
              ),
              Flexible(
                child: Obx(() {
                  final double width =
                      (Responsive.isDesktop(context) ||
                          Responsive.isDesktopLarg(context))
                      ? double.infinity
                      : selectItem.value == 0
                      ? 0
                      : Responsive.getWidth(context) * 0.5;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    // height: Responsive.getHeight(context),
                    width: width,
                    color: AppColors.background,
                    child: Column(children: [const SideContent()]),
                  );
                }),
              ),
              Container(
                width: 90,
                // height: Responsive.getHeight(context),
                color: AppColors.primary,
                child: Column(
                  children: [
                    // const SizedBox(height: 60),
                    // InkWell(
                    //   onTap: () {
                    //     if(Responsive.isDesktop(context) || Responsive.isDesktopLarg(context))
                    //     {
                    //       if (selectItem.value == 10) {
                    //       if (Responsive.isTablet(context)) {
                    //         selectItem.value = 0;
                    //       }
                    //     } else {
                    //       selectItem.value = 10;
                    //     }
                    //     }

                    //   },
                    //   child: const CircleAvatar(
                    //     maxRadius: 30,
                    //     child: Icon(IconsaxPlusLinear.user, size: 30),
                    //   ),
                    // ),
                    // const SizedBox(height: 20),
                    // const EndItem(),
                    EndItem(),

                    Item(
                      index: 2,
                      icon: IconsaxPlusLinear.personalcard,
                      text: 'پروفایل',
                    ),
                    const EndItem(),
                    Item(
                      index: 1,
                      icon: IconsaxPlusLinear.calendar,
                      text: 'تقویم',
                    ),

                    const EndItem(),
                    Item(
                      index: 3,
                      icon: IconsaxPlusLinear.message,
                      text: 'گفت و گو',
                      onTap: () {
                        Alert.info('بزودی...');
                      },
                    ),
                    const EndItem(),
                    Item(
                      index: 4,
                      icon: IconsaxPlusLinear.setting_2,
                      text: 'تنظیمات',
                    ),
                    EndItem(),
                    const Expanded(child: SizedBox()),
                    // Item(icon: IconsaxPlusLinear.arrow_swap_horizontal, text: 'حساب ها', index: 10)  ,
                    if (!Platform.isAndroid && !Platform.isIOS) const EndItem(),
                    if (!Platform.isAndroid && !Platform.isIOS)
                      Item(
                        icon: IconsaxPlusLinear.logout,
                        text: 'خروج',
                        index: 11,
                        onTap: () {
                          Get.toNamed(RoutesName.ACCOUNTS);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SideContent extends StatefulWidget {
  const SideContent({super.key});

  @override
  State<SideContent> createState() => _SideContentState();
}

class _SideContentState extends State<SideContent> {
  late final Widget _calendar = const _CalendarSideContent();
  late final Widget _profilePage = Builder(
    builder: (context) =>
        ComponentHost.profile?.call(context) ?? const SizedBox.shrink(),
  );
  late final Widget _settingPage = Builder(
    builder: (context) =>
        ComponentHost.settings?.call(context) ?? const SizedBox.shrink(),
  );
  late final Widget _accounts = Builder(
    builder: (context) =>
        ComponentHost.accounts?.call(context) ?? const SizedBox.shrink(),
  );

  Widget _contentFor(int index, BuildContext context) {
    switch (index) {
      case 1:
        return _calendar;
      case 2:
        return SizedBox(
          height: Responsive.getHeight(context) - 60,
          child: _profilePage,
        );
      case 4:
        return SizedBox(
          height: Responsive.getHeight(context) - 60,
          child: _settingPage,
        );
      case 10:
        return _accounts;
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => _contentFor(selectItem.value, context));
  }
}

class _CalendarSideContent extends StatefulWidget {
  const _CalendarSideContent();

  @override
  State<_CalendarSideContent> createState() => _CalendarSideContentState();
}

class _CalendarSideContentState extends State<_CalendarSideContent> {
  @override
  Widget build(BuildContext context) =>
      ComponentHost.calendar?.call(context) ?? const SizedBox.shrink();
}
