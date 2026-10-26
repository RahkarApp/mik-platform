// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_pages/login/utils/getFirstData.dart';
import 'package:widget_loading/widget_loading.dart';

import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/linearProgress.dart';

RxInt getDataFirstMaxSize = 0.obs;
RxInt getDataFirstsavedSize = 0.obs;

class GetDataScreen extends GetView {
  const GetDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async {
        await GetFirstData.get();
        return '';
      },
      loadingDuration: 1500,
      child: (data) => Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 30),
            alignment: Alignment.center,
            child: Image.asset(
              'packages/mik_pages/assets/images/login/loading.gif',
              height: 300,
            ),
          ),
          const Text('درحال دریافت اطلاعات از سرور...'),
          WiperLoading(
            wiperWidth: 10,
            wiperColor: AppColors.primary,
            child: const Text('درحال دریافت اطلاعات از سرور...'),
          ),
          const SizedBox(height: 50),
          Container(
            alignment: Alignment.center,
            color: AppColors.background,
            margin: const EdgeInsets.symmetric(horizontal: 25),
            child: Obx(
              () => getDataFirstMaxSize.value > 0
                  ? MyLinearProgress(
                      colors: AppColors.primary,
                      value:
                          (getDataFirstsavedSize.value /
                          getDataFirstMaxSize.value),
                    )
                  : Container(),
            ),
          ),
          SizedBox(height: 30),
          Obx(
            () => dbUpdate.isTrue
                ? Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      children: [
                        const Text(
                          'درحال بروزرسانی دیتابیس و ایجاد داده‌های جدید مطابق با آخرین آپدیت «میک»',
                        ),
                        MyLinearProgress(
                          colors: AppColors.secondary,
                          value: (dbUpdateCurrent.value / dbUpdateLength.value),
                        ),
                        const Text('لطفا تا پایان عملیات منتظر بمانید...'),
                      ],
                    ),
                  )
                : Container(),
          ),
          Expanded(child: Container()),
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 30),
            child: Image.asset(
              'packages/mik_pages/assets/images/logo/logo.png',
              width: 70,
            ),
          ),
        ],
      ),
    );
  }
}
