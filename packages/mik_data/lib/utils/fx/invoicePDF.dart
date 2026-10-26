import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widget_loading/widget_loading.dart';

import '../../models/models.dart';
import '../pdf/receipt.dart';
import '../variable.dart';

RxBool _generateWait = false.obs;

class InvoicePDF {
  static void setting(BuildContext context, InvoiceDB item) {
    if (settings == null) {
      Alert.error('تنظیمات فاکتور بارگذاری نشده است.');
      return;
    }
    RxString pageSize =
        (settings!.factorSize == 'a4' ? 'کاغذ عمودی' : 'کاغذ افقی').obs;
    RxString fileType =
        ((settings!.factorType == null || settings!.factorType == 0)
                ? 'PDF'
                : 'عکس')
            .obs;
    RxString isRial =
        ((settings!.factorIsRial ?? false) ? 'قیمت به ریال' : 'قیمت به تومان')
            .obs;
    RxString link =
        ((settings!.factorLink ?? false)
                ? 'ارسال لینک و متن'
                : 'بدون لینک و متن')
            .obs;
    RxString vat =
        ((settings!.factorVat ?? false) ? 'نمایش مالیات' : 'عدم نمایش مالیات')
            .obs;
    MyBottomSheet.view(
      context,
      child: (scrollController) => Obx(
        () => CircularWidgetLoading(
          loading: _generateWait.value,
          dotRadius: 2,
          maxLoadingCircleSize: 30,
          dotColor: AppColors.primary,
          loadingDuration: const Duration(milliseconds: 1000),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  MyTab(
                    tab: const ['PDF', 'عکس'],
                    value: fileType,
                    color: AppColors.secondary,
                    callback: (v) {
                      fileType.value = v;
                    },
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => MyTab(
                      tab: const ['کاغذ عمودی', 'کاغذ افقی'],
                      color: fileType.value == 'عکس'
                          ? AppColors.disable
                          : AppColors.primaryLite,
                      value: pageSize,
                      callback: (v) {
                        if (fileType.value != 'عکس') pageSize.value = v;
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  MyTab(
                    tab: const ['قیمت به ریال', 'قیمت به تومان'],
                    color: AppColors.primaryLite,
                    value: isRial,
                    callback: (v) {
                      isRial.value = v;
                    },
                  ),
                  const SizedBox(height: 10),
                  MyTab(
                    tab: const ['نمایش مالیات', 'عدم نمایش مالیات'],
                    color: AppColors.primaryLite,
                    value: vat,
                    callback: (v) {
                      vat.value = v;
                    },
                  ),
                  const SizedBox(height: 10),
                  MyTab(
                    tab: const ['ارسال لینک و متن', 'بدون لینک و متن'],
                    color: AppColors.primaryLite,
                    value: link,
                    callback: (v) {
                      link.value = v;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: BTN(
                      name: 'اشتراک‌گذاری',
                      color: AppColors.primaryDark,
                      icon: IconsaxPlusLinear.share,
                      onTap: () async {
                        if (_generateWait.value) return;
                        settings!.factorType = fileType.value == 'PDF' ? 0 : 1;
                        settings!.factorSize = pageSize.value == 'کاغذ عمودی'
                            ? 'a4'
                            : 'la4';
                        settings!.factorIsRial = isRial.value == 'قیمت به ریال'
                            ? true
                            : false;
                        settings!.factorLink = link.value == 'ارسال لینک و متن'
                            ? true
                            : false;
                        settings!.factorVat = vat.value == 'نمایش مالیات'
                            ? true
                            : false;
                        await generate(item, closeSettings: true);
                      },
                    ),
                  ),
                  Flexible(
                    child: BTN(
                      name: 'انصراف',
                      type: BTNType.cancel,
                      onTap: () => Get.back(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      // h: 360,
      title: 'اشتراک‌گذاری فایل فاکتور',
    );
  }

  static Future<void> generate(
    InvoiceDB item, {
    bool closeSettings = false,
  }) async {
    if (_generateWait.value) return;
    _generateWait.value = true;
    try {
      final config = settings;
      if (config == null) throw StateError('Invoice settings are not loaded.');
      if (item.uid == null || item.uid!.isEmpty) {
        throw StateError('Invoice UID is missing.');
      }
      // Persist share preferences locally; generating a file also works offline.
      if (settingsData.isOpen && settingsData.isNotEmpty) {
        await settingsData.putAt(0, config);
      }
      final customer = person.values.where((p) => p.uid == item.personUID);
      final customerName = customer.isEmpty
          ? 'مشتری'
          : customer.first.name ?? 'مشتری';
      final seller = profile.isEmpty ? '' : profile.getAt(0)?.name ?? '';
      final lines = <ReceiptLine>[];
      for (final entry in (item.items ?? {}).entries) {
        final matches = product.values.where((p) => p.uid == entry.key);
        final name = matches.isEmpty
            ? entry.key.toString()
            : matches.first.name ?? entry.key.toString();
        for (final variant in entry.value as List) {
          final vat = variant['vat'];
          lines.add(
            ReceiptLine(
              name: name,
              amount: _number(variant['amount']),
              price: _number(variant['price']),
              vatPercent: vat is Map
                  ? _number(vat['percent']).clamp(0, 100)
                  : 0,
            ),
          );
        }
      }
      final subtotal = lines.fold<num>(0, (total, line) => total + line.total);
      num adjustment = 0;
      for (final parameter in item.parameters ?? []) {
        final value = _number(parameter['amount']);
        final amount = parameter['type'] == 'fix'
            ? value
            : subtotal * value / 100;
        if (parameter['mode'] == 'add') adjustment += amount;
        if (parameter['mode'] == 'ded') adjustment -= amount;
      }
      final files = await ReceiptPDF.factorGenerate(
        ReceiptData(
          uid: item.uid!,
          number: '${item.id ?? ''}',
          seller: seller,
          customer: customerName,
          date: item.date?.split('T').first ?? '',
          lines: lines,
          adjustment: adjustment,
          shipping: _number(item.shipping?['cost']),
          note: [
            item.description,
            config.factorText,
          ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n'),
        ),
        asImage: config.factorType == 1,
        landscape: config.factorSize == 'la4',
        isRial: config.factorIsRial ?? false,
        showVat: config.factorVat ?? false,
      );
      final renderBox = Get.context?.findRenderObject();
      final shareOrigin = renderBox is RenderBox && renderBox.hasSize
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : null;
      if (closeSettings && Get.isBottomSheetOpen == true) Get.back();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            for (final file in files)
              XFile.fromData(
                file.bytes,
                mimeType: file.mimeType,
                name: file.name,
              ),
          ],
          sharePositionOrigin: shareOrigin,
          fileNameOverrides: [for (final file in files) file.name],
          subject: 'فاکتور شماره ${item.id ?? ''} - $seller',
          text: config.factorLink == true
              ? 'سلام $customerName عزیز\nhttps://onmik.ir/invoice/${item.uid}\n$seller'
              : null,
        ),
      );
    } catch (error) {
      debugPrint('Invoice file generation failed: $error');
      Alert.error(
        'ساخت یا اشتراک‌گذاری فایل فاکتور انجام نشد. دوباره تلاش کنید.',
      );
    } finally {
      _generateWait.value = false;
    }
  }

  static num _number(Object? value) =>
      value is num ? value : num.tryParse('$value') ?? 0;
}
