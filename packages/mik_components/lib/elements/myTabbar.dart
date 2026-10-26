import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

class MyTabBar extends GetView {
  List<String> tabs;
  List<bool>? badge;
  bool transparent;
  int currentIndex;
  ValueSetter index;
  bool? divider;
  Color? color;
  Color? bgColor;

  MyTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.index,
    this.transparent = false,
    this.badge,
    this.divider,
    this.color,
    this.bgColor,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    if (badge != null && badge!.length != tabs.length) {
      return const Text(
        'لیست تب و لیست بچ متناسب نیست!',
        style: TextStyle(color: Colors.red),
      );
    }
    return Material(
      elevation: (divider ?? true) ? 2 : 0,
      child: Obx(
        () => darkMode.isTrue || darkMode.isFalse
            ? Container(
                height: (divider ?? true) ? 60 : 40,
                width: Get.width,
                color:
                    bgColor ??
                    (darkMode.isFalse
                        ? AppColors.background
                        : AppColors.backgroundDarkMode),
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: tabs
                      .map(
                        (t) => Flexible(
                          fit: FlexFit.tight,
                          child: InkWell(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                            onTap: () => index(tabs.indexOf(t)),
                            child: Stack(
                              children: [
                                if (badge != null && badge![tabs.indexOf(t)])
                                  Container(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      left: 15,
                                    ),
                                    alignment: Alignment.topLeft,
                                    child: CircleAvatar(
                                      maxRadius: 5,
                                      backgroundColor: AppColors.secondary,
                                    ),
                                  ),
                                Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: tabs.indexOf(t) == currentIndex
                                          ? BorderSide(
                                              color: color ?? AppColors.primary,
                                              width: 3,
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Text(
                                    t,
                                    style: tabs.indexOf(t) == currentIndex
                                        ? const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              )
            : Container(),
      ),
    );
  }
}
