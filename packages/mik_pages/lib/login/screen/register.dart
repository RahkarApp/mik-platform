import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/acquisition_source.dart';
import 'package:mik_data/source/remote/models/business_acquisition.dart';
import 'package:mik_data/source/remote/models/business_activity.dart';
import 'package:mik_data/source/remote/models/onboarding_data.dart';
import 'package:mik_data/source/remote/models/onboarding_result.dart';
import 'package:mik_data/source/remote/models/business_session.dart';
import 'package:mik_data/utils/fx/auth.dart';
import 'package:mik_data/utils/fx/business.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_variables/variable.dart';

import '../components/activity_picker.dart';

class RegisterScreen extends StatefulWidget {
  final BusinessFX? business;
  final Future<void> Function(OnboardingResult result)? onCompleted;
  final Future<void> Function()? onLogout;
  const RegisterScreen({
    super.key,
    this.business,
    this.onCompleted,
    this.onLogout,
  });
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController(),
      _firstName = TextEditingController(),
      _lastName = TextEditingController(),
      _referral = TextEditingController(),
      _field = TextEditingController(),
      _sourceText = TextEditingController();
  final _busy = false.obs, _pending = false.obs;
  final _activities = <BusinessActivity>[];
  String? _source;
  late final _business =
      widget.business ?? BusinessFX(session: AuthFX.forApp('mik'));

  Future<Object> _prepare() async {
    try {
      final previous = _business.attempt ?? await _business.restoreAttempt();
      if (!mounted) return '';
      if (previous != null) {
        final data = previous.data;
        _name.text = data.businessName;
        _firstName.text = data.firstName;
        _lastName.text = data.lastName ?? '';
        _referral.text = data.referralCode ?? '';
        _activities
          ..clear()
          ..addAll(data.activities);
        _source = data.acquisition.sourceCode;
        _sourceText.text = data.acquisition.description ?? _source!;
        _pending.value = true;
        _updateField();
      }
      return '';
    } catch (error) {
      throw BusinessFX.message(error);
    }
  }

  void _updateField() => _field.text = _activities.isEmpty
      ? ''
      : '${_activities.length} حوزه و ${_activities.fold<int>(0, (n, item) => n + item.subfieldCodes.length)} زیرحوزه';
  Future<void> _chooseActivities() async {
    if (_busy.value || _pending.value) return;
    final result = await MyBottomSheet.view(
      context,
      title: 'انتخاب حوزه فعالیت',
      initialChildSize: 0.8,
      child: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: ActivityPicker(business: _business, selected: _activities),
      ),
    );
    if (!mounted || result is! List<BusinessActivity>) return;
    _activities
      ..clear()
      ..addAll(result);
    _updateField();
  }

  OnboardingData? _data() {
    if (_firstName.text.trim().isEmpty) {
      Alert.error('نام مدیر را وارد کنید.');
      return null;
    }
    if (_name.text.trim().isEmpty) {
      Alert.error('نام مجموعه را وارد کنید.');
      return null;
    }
    if (_activities.isEmpty ||
        _activities.length > 20 ||
        _activities.any(
          (e) => e.subfieldCodes.isEmpty || e.subfieldCodes.length > 30,
        )) {
      Alert.error('حوزه و زیرحوزه فعالیت را انتخاب کنید.');
      return null;
    }
    if (_source == null) {
      Alert.error('نحوه آشنایی با میک را انتخاب کنید.');
      return null;
    }
    final referral = API.normalizeDigits(_referral.text).trim().toUpperCase();
    if (referral.isNotEmpty &&
        !RegExp(r'^(?:[1-9][0-9]{7}|M[A-Z0-9_-]+)$').hasMatch(referral)) {
      Alert.error(
        'کد معرف باید کد ۸ رقمی کسب‌وکار یا کد بازاریاب با پیشوند M باشد.',
      );
      return null;
    }
    final source = AcquisitionSource.values.firstWhere(
      (e) => e.code == _source,
    );
    return OnboardingData(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
      businessName: _name.text.trim(),
      activities: _activities,
      acquisition: BusinessAcquisition(
        sourceCode: source.code,
        description: source.label,
      ),
      referralCode: referral.isEmpty ? null : referral,
    );
  }

  Future<void> _send() async {
    if (_busy.value) return;
    final data = _business.attempt?.data ?? _data();
    if (data == null) return;
    FocusScope.of(context).unfocus();
    _busy.value = true;
    try {
      final result = await _business.onboard(data);
      if (!mounted) return;
      if (widget.onCompleted != null) {
        await widget.onCompleted!(result);
      } else {
        Get.offAllNamed(
          RoutesName.WELCOME,
          arguments: BusinessSession.fromOnboarding(result),
        );
      }
    } catch (error) {
      if (mounted) Alert.error(BusinessFX.message(error));
      if (error is AuthError && error.requiresLogin && mounted) {
        if (widget.onLogout != null) {
          await widget.onLogout!();
        } else {
          Get.offAllNamed(RoutesName.LOGIN);
        }
      }
    } finally {
      if (mounted) {
        _pending.value = _business.attempt != null;
        _busy.value = false;
      }
    }
  }

  @override
  void dispose() {
    for (final ctl in [
      _name,
      _firstName,
      _lastName,
      _referral,
      _field,
      _sourceText,
    ]) {
      ctl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Main(
    initState: _prepare,
    child: (_) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Column(
          children: [
            Image.asset(
              'packages/mik_pages/assets/images/onboard/IMG_2894.png',
              height: constraints.maxHeight * 0.24,
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
                color: darkMode.isFalse
                    ? Colors.grey.shade100
                    : Colors.grey.shade900,
              ),
              child: Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تکمیل ثبت‌نام',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'یک قدم تا مدیریت حرفه‌ای و پیشرفته کسب و کارت',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    if (_pending.value)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'ثبت قبلی هنوز تأیید نشده است. برای دریافت نتیجه، همان اطلاعات را دوباره ارسال کنید.',
                        ),
                      ),
                    Input(
                      key: const ValueKey('owner-first-name'),
                      controller: _firstName,
                      name: 'نام مدیر',
                      require: true,
                      maxLength: 100,
                      readOnly: _busy.value || _pending.value,
                    ),
                    Input(
                      key: const ValueKey('owner-last-name'),
                      controller: _lastName,
                      name: 'نام خانوادگی مدیر',
                      maxLength: 100,
                      readOnly: _busy.value || _pending.value,
                    ),
                    Input(
                      key: const ValueKey('business-name'),
                      controller: _name,
                      name: 'نام مجموعه',
                      require: true,
                      maxLength: 200,
                      readOnly: _busy.value || _pending.value,
                    ),
                    Input(
                      key: const ValueKey('business-activities'),
                      controller: _field,
                      name: 'حوزه‌فعالیت',
                      require: true,
                      readOnly: true,
                      onTap: _chooseActivities,
                    ),
                    if (_pending.value)
                      Input(
                        controller: _sourceText,
                        name: 'نحوه آشنایی',
                        readOnly: true,
                      )
                    else
                      Dropdown(
                        search: false,
                        require: true,
                        hint: false,
                        name: 'نحوه آشنایی',
                        defaultValue: AcquisitionSource.values
                            .where((e) => e.code == _source)
                            .firstOrNull
                            ?.label,
                        disable: _busy.value,
                        items_String: AcquisitionSource.values
                            .map((e) => e.label)
                            .toList(),
                        onChange: (value) {
                          final source = AcquisitionSource.values.firstWhere(
                            (e) => e.label == value,
                          );
                          _source = source.code;
                          _sourceText.text = source.label;
                        },
                      ),
                    Input(
                      key: const ValueKey('business-referral'),
                      controller: _referral,
                      name: 'کد معرف',
                      maxLength: 64,
                      readOnly: _busy.value || _pending.value,
                    ),
                    const SizedBox(height: 15),
                    BTN(
                      onTap: _send,
                      height: 50,
                      navigate: true,
                      inLoad: _busy.value,
                      name: _pending.value ? 'تلاش مجدد' : 'ثبت نام و ورود',
                      type: BTNType.ok,
                    ),
                    if (widget.onLogout != null)
                      TextButton(
                        onPressed: _busy.value ? null : widget.onLogout,
                        child: const Text('خروج از حساب'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
