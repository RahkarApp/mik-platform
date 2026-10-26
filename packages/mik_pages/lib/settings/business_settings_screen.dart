import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/business_settings_detail.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/business_settings.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class BusinessSettingsScreen extends StatefulWidget {
  final String appId;
  const BusinessSettingsScreen({required this.appId, super.key});
  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenController extends GetxController {
  final inputs = {
    for (final path in BusinessSettingsDetail.numbers.keys)
      path: TextEditingController(),
  };
  BusinessSettingsFX? fx;
  BusinessSettingsDetail? current;
  Map<String, dynamic> values = {};
  bool loading = true, saving = false, conflict = false;
  String? error;
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  late final _page = _BusinessSettingsScreenController();

  static const labels = {
    'OLDEST_DUE_FIRST': 'سررسید قدیمی‌تر',
    'OLDEST_FIRST': 'ثبت قدیمی‌تر',
    'MANUAL': 'دستی',
    'AUTO': 'خودکار',
    'SINGLE_WAREHOUSE': 'از یک انبار',
    'MULTI_WAREHOUSE': 'از چند انبار',
    'PAYMENT_FIRST': 'اولویت با پرداخت',
    'PAID': 'تسویه‌شده',
    'PARTIALLY_PAID': 'بخشی پرداخت‌شده',
    'UNPAID': 'پرداخت‌نشده',
  };
  static const numberLabels = {
    'inventory.reservation.posTimeoutMinutes': 'رزرو فروش حضوری (دقیقه)',
    'inventory.reservation.onlineTimeoutMinutes': 'رزرو فروش آنلاین (دقیقه)',
    'inventory.reservation.maxExtensions': 'حداکثر دفعات تمدید رزرو',
    'inventory.reservation.maxLifetimeMinutes': 'حداکثر عمر رزرو (دقیقه)',
  };

  bool get locked =>
      _page.loading ||
      _page.saving ||
      _page.conflict ||
      _page.fx?.canEdit != true ||
      _page.fx?.hasPending == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    for (final input in _page.inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  void apply(BusinessSettingsDetail value) {
    _page.current = value;
    _page.values = value.editable;
    for (final entry in _page.inputs.entries) {
      entry.value.text = '${_page.values[entry.key]}';
    }
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    {
      _page.loading = true;
      _page.error = null;
      _page.current = null;
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= BusinessSettingsFX.forContext(active);
      final result = await _page.fx!.load();
      if (mounted) {
        {
          apply(result);
          _page.conflict = false;
          _page.update();
        }
      }
    } catch (failure) {
      if (mounted) {
        _page.error = BusinessSettingsFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<void> save() async {
    if (_page.saving ||
        _page.loading ||
        _page.current == null ||
        _page.fx?.canEdit != true ||
        _page.conflict) {
      return;
    }
    if (!_page.fx!.hasPending) {
      try {
        for (final entry in _page.inputs.entries) {
          final text = entry.value.text.trim().toEnglishDigit();
          if (!RegExp(r'^\d{1,4}$').hasMatch(text)) {
            throw const FormatException(
              'زمان و تعداد رزرو را به‌صورت عدد صحیح وارد کنید.',
            );
          }
          _page.values[entry.key] = int.parse(text);
        }
        final changes = _page.current!.changes(_page.values);
        if (changes.isEmpty) {
          Alert.info('تغییری برای ذخیره وجود ندارد.');
          return;
        }
      } on FormatException catch (failure) {
        Alert.error(failure.message, context: context);
        return;
      }
    }
    {
      _page.saving = true;
      _page.error = null;
      _page.update();
    }
    try {
      final result = await _page.fx!.save(_page.current!, _page.values);
      if (!mounted) return;
      {
        apply(result);
        _page.update();
      }
      Alert.success('تنظیمات کسب‌وکار با موفقیت ذخیره شد.');
    } catch (failure) {
      if (!mounted) return;
      if (failure is AuthError && failure.code == 'REVISION_CONFLICT') {
        _page.conflict = true;
      }
      if (failure is AuthError &&
          (failure.requiresLogin ||
              failure.statusCode == 403 ||
              failure.code == 'SELECTION_CHANGED')) {
        _page.current = null;
      }
      _page.error = BusinessSettingsFX.message(failure);
      Alert.error(_page.error!, context: context);
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  Widget toggle(String path, String title) => Column(
    key: ValueKey(path),
    children: [
      Text(title),
      IgnorePointer(
        ignoring: locked,
        child: MyTab(
          tab: const ['فعال', 'غیرفعال'],
          value: (_page.values[path] == true ? 'فعال' : 'غیرفعال').obs,
          callback: (String value) {
            _page.values[path] = value == 'فعال';
            _page.update();
          },
        ),
      ),
    ],
  );
  Widget option(String path, String title) => Column(
    children: [
      Text(title),
      MiniBTN(
        name: labels[_page.values[path]] ?? '',
        icon: IconsaxPlusLinear.arrow_down_1,
        noFlex: true,
        onTap: locked
            ? null
            : () async {
                final value = await MyBottomSheet.view(
                  context,
                  title: title,
                  child: (_) => Column(
                    children: [
                      for (final code in BusinessSettingsDetail.choices[path]!)
                        BTN(
                          name: labels[code]!,
                          onTap: () => Get.back(result: code),
                        ),
                    ],
                  ),
                );
                if (mounted && value is String && !locked) {
                  {
                    _page.values[path] = value;
                    _page.update();
                  }
                }
              },
      ),
    ],
  );

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_BusinessSettingsScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'تنظیمات کسب‌وکار'),
        child: (_) => Column(
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null)
              Text(_page.error!, textAlign: TextAlign.center),
            if (_page.error != null || _page.conflict)
              BTN(
                name: 'دریافت دوباره تنظیمات',
                disabled: _page.loading || _page.saving,
                onTap: load,
              ),
            if (_page.current != null) ...[
              if (_page.fx?.canEdit != true)
                const Text('تنظیمات فقط قابل مشاهده است؛ مجوز تغییر ندارید.'),
              if (_page.fx?.hasPending == true)
                const Text(
                  'نتیجه ذخیره قبلی مشخص نیست؛ همان درخواست را پیگیری کنید.',
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        toggle('accounting.allowCreditSales', 'فروش اعتباری'),
                        option(
                          'accounting.allocationPolicy',
                          'ترتیب تخصیص پرداخت',
                        ),
                        MyDivider(),
                        toggle(
                          'tax.taxpayerSystemEnabled',
                          'استفاده از سامانه مؤدیان',
                        ),
                        const Text(
                          'این گزینه به‌تنهایی به معنی ارسال فاکتور به سامانه مؤدیان نیست.',
                        ),
                        MyDivider(),
                        option(
                          'inventory.itemFulfillmentMode',
                          'تأمین هر ردیف فاکتور',
                        ),
                        for (final entry in _page.inputs.entries)
                          Input(
                            key: ValueKey(entry.key),
                            name: numberLabels[entry.key]!,
                            controller: entry.value,
                            readOnly: locked,
                            require: true,
                            maxLength: 4,
                            keyboardType: TextInputType.number,
                          ),
                        MyDivider(),
                        option(
                          'inventory.supplyAllocation.mode',
                          'تخصیص موجودی به سفارش‌ها',
                        ),
                        option(
                          'inventory.supplyAllocation.priority',
                          'اولویت تخصیص موجودی',
                        ),
                        const Text('سفارش‌های واجد شرایط تخصیص موجودی'),
                        for (final code
                            in BusinessSettingsDetail.paymentStatuses)
                          MiniBTN(
                            name:
                                '${(_page.values[BusinessSettingsDetail.paymentPath] as List).contains(code) ? '✓ ' : ''}${labels[code]}',
                            noFlex: true,
                            icon: IconsaxPlusLinear.tick_circle,
                            onTap: locked
                                ? null
                                : () {
                                    final selected = List<String>.from(
                                      _page.values[BusinessSettingsDetail
                                              .paymentPath]
                                          as List,
                                    );
                                    selected.contains(code)
                                        ? selected.remove(code)
                                        : selected.add(code);
                                    _page.values[BusinessSettingsDetail
                                            .paymentPath] =
                                        selected;
                                    _page.update();
                                  },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_page.fx?.canEdit == true)
                BTN(
                  name: _page.fx!.hasPending
                      ? 'پیگیری ذخیره قبلی'
                      : 'ذخیره تنظیمات',
                  disabled: _page.loading || _page.saving || _page.conflict,
                  onTap: save,
                ),
            ] else if (!_page.loading)
              const Expanded(
                child: Center(child: Text('تنظیمات قابل دریافت نیست.')),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget buildBusinessSettingsRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return BusinessSettingsScreen(appId: args.required<String>('appId'));
}
