// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mik_components/base/alert.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_utils/public/analytics.dart';
import 'package:mik_data/source/remote/models/auth_session.dart';
import 'package:mik_data/source/remote/models/business_session.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_data/utils/fx/auth.dart';
import 'package:mik_data/utils/fx/business_context.dart';

import '../components/success.dart';
import 'mik_account.dart';

import 'package:mik_variables/variable.dart';

import 'package:mik_pages/login/utils/login.dart';
import 'package:sms_autofill/sms_autofill.dart';

import 'package:mik_components/elements/bottomSheet.dart';

RxBool authCode = false.obs, waitForCall = false.obs, loading = false.obs;

RxInt resend = 120.obs;
StreamSubscription? authListen;

class LoginScreen extends StatefulWidget {
  final String title;
  final String appId;
  final AuthFX? session;
  final Future<void> Function(AuthSession session, bool registration)?
  onAuthenticated;
  final Future<void> Function(BusinessSession)? onBusinessSelected;
  final int otpLength;
  final bool allowRegistration;
  final Future<bool> Function(BuildContext, String, String)? onSubmitMobile;
  final Future<dynamic> Function(String, String)? onAuth;
  final Future<dynamic> Function(String)? onCallToLogin;
  const LoginScreen({
    super.key,
    this.title = 'ورود و ثبت‌نام',
    this.appId = 'mik',
    this.session,
    this.onAuthenticated,
    this.onBusinessSelected,
    this.otpLength = 5,
    this.allowRegistration = true,
    this.onSubmitMobile,
    this.onAuth,
    this.onCallToLogin,
  });

  void condition(BuildContext context) => showLoginConditions(context);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobilectl = TextEditingController();
  final _mobileF = FocusNode();
  final _codeF = FocusNode();
  final _codectl = TextEditingController();
  Timer? _resendTimer;
  final RxBool _verified = false.obs;
  late final AuthFX _session = widget.session ?? AuthFX.forApp(widget.appId);

  Future<bool> _submitMobile(
    BuildContext context,
    String act,
    String mobile,
  ) async {
    if (widget.onSubmitMobile != null) {
      return widget.onSubmitMobile!(context, act, mobile);
    }
    return LoginFunc.submitMobile(
      context,
      act,
      mobile,
      appId: widget.appId,
      allowRegistration: widget.allowRegistration,
      session: _session,
    );
  }

  Future<dynamic> _auth(String mobile, String code) => widget.onAuth != null
      ? widget.onAuth!(mobile, code)
      : LoginFunc.auth(mobile, code, appId: widget.appId, session: _session);

  Future<void> _finished() async {
    if (!mounted) return;
    _resendTimer?.cancel();
    _verified.value = true;
    final session = _session.current;
    if (session != null) await widget.onAuthenticated?.call(session, reg);
  }

  Future<void> _logout() async {
    if (loading.value) return;
    loading.value = true;
    try {
      await _session.signOut();
    } catch (error) {
      if (mounted) Alert.error(API.loginError(error, appId: widget.appId));
    } finally {
      if (mounted) {
        BusinessContext.clear(widget.appId);
        PermissionAccess.clear();
        permissions.clear();
        branchs.clear();
        warehouses.clear();
        _verified.value = false;
        authCode.value = false;
        reg = false;
        _codectl.clear();
        _mobilectl.clear();
        loading.value = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) init(context);
    });
  }

  void _startResendTimer() {
    if (!mounted) return;
    _resendTimer?.cancel();
    resend.value = 120;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resend.value > 0) resend.value--;
      if (resend.value == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    authListen?.cancel();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SmsAutoFill().unregisterListener();
    }
    _mobilectl.dispose();
    _codectl.dispose();
    _mobileF.dispose();
    _codeF.dispose();
    super.dispose();
  }

  Future<String> init(BuildContext context) async {
    reg = false;
    authCode.value = false;
    waitForCall.value = false;
    loading.value = true;
    try {
      final restored = await _session.restore();
      if (!mounted) return '';
      _verified.value = restored;
      if (restored && _session.current != null) {
        await widget.onAuthenticated?.call(_session.current!, false);
      }
    } catch (error) {
      if (mounted) Alert.error(API.loginError(error, appId: widget.appId));
    } finally {
      if (mounted) loading.value = false;
    }
    if (!mounted || _verified.isTrue) return '';
    _mobileF.requestFocus();
    try {
      await Analytics.pageView();
    } catch (error) {
      debugPrint('Login analytics unavailable: $error');
    }
    if (mounted && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await SmsAutoFill().listenForCode(
          smsCodeRegexPattern: '([0-9]{${widget.otpLength}})',
        );
      } catch (error) {
        debugPrint('SMS autofill unavailable: $error');
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _verified.isTrue
          ? widget.onAuthenticated == null
                ? MikAccountScreen(
                    session: _session,
                    onLogout: _logout,
                    onSelected: widget.onBusinessSelected,
                  )
                : LoginSuccess(onLogout: _logout)
          : Scaffold(
              body: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Obx(
                        () => Image.asset(
                          authCode.isFalse
                              ? 'packages/mik_pages/assets/images/onboard/IMG_2894.png'
                              : 'packages/mik_pages/assets/images/onboard/IMG_2890.png',
                        ),
                      ),
                    ),
                    Container(
                      //height: 330,
                      //  width: Get.width,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        color: darkMode.isFalse
                            ? Colors.grey.shade100
                            : Colors.grey.shade900,
                      ),
                      child: Column(
                        children: [
                          Container(
                            alignment: Alignment.center,
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          Container(
                            alignment: Alignment.topRight,
                            child: Obx(
                              () => authCode.isFalse
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('سلام!'),
                                        Text(
                                          'لطفا شماره موبایل خود را وارد کنید.',
                                        ),
                                      ],
                                    )
                                  : Text(
                                      'کد تایید ${widget.otpLength == 6 ? '۶' : '۵'} رقمی برای ${_mobilectl.text} ارسال شد',
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Obx(
                            () => authCode.isFalse
                                ? Input(
                                    controller: _mobilectl,
                                    name: '',
                                    style: 2,
                                    rightPadding: 0,
                                    focusNode: _mobileF,
                                    hintText: '09123456789',
                                    keyboardType: TextInputType.phone,
                                    onChanged: (v) {
                                      // if (v.length == 11) {
                                      //   _mobileF.unfocus();
                                      // }
                                    },
                                    maxLength: 11,
                                  )
                                : Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: darkMode.isFalse
                                          ? AppColors.background
                                          : AppColors.backgroundDarkMode,
                                    ),
                                    child: PinFieldAutoFill(
                                      controller: _codectl,
                                      focusNode: _codeF,
                                      decoration: BoxTightDecoration(
                                        radius: const Radius.circular(10),
                                        strokeWidth: 0,
                                        strokeColor: darkMode.value
                                            ? AppColors.primaryLite
                                            : AppColors.primary,
                                      ),
                                      codeLength: widget.otpLength,
                                      onCodeChanged: (v) async {
                                        if (v != null &&
                                            v.length == widget.otpLength &&
                                            loading.isFalse) {
                                          _codeF.unfocus();
                                          loading.value = true;
                                          try {
                                            var res = await _auth(
                                              _mobilectl.text,
                                              v,
                                            );
                                            if (!mounted) return;
                                            if (res == true) {
                                              await _finished();
                                            } else if (res == 'false') {
                                              _codectl.clear();
                                            } else if (res == 'again') {
                                              _codectl.clear();
                                              _mobilectl.clear();
                                              authCode.value = false;
                                            }
                                          } catch (error) {
                                            if (mounted) {
                                              Alert.error(
                                                'ورود انجام نشد. دوباره تلاش کنید.',
                                              );
                                            }
                                            debugPrint(
                                              'Login verification failed: $error',
                                            );
                                          } finally {
                                            loading.value = false;
                                          }
                                        }
                                      },
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          Obx(
                            () => authCode.isFalse
                                ? Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () =>
                                            showLoginConditions(context),
                                        child: Text(
                                          'شرایط استفاده از میک و حریم‌خصوصی',
                                          style: TextStyle(
                                            color: darkMode.value
                                                ? AppColors.primaryLite
                                                : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const Text(' را میپذیرم.'),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (loading.value) return;
                                          _resendTimer?.cancel();
                                          reg = false;
                                          authCode.value = false;
                                          _codectl.clear();
                                          _mobilectl.clear();
                                          _mobileF.requestFocus();
                                        },
                                        child: Text(
                                          'تغییر شماره موبایل',
                                          style: TextStyle(
                                            color: darkMode.isTrue
                                                ? AppColors.background
                                                : darkMode.value
                                                ? AppColors.primaryLite
                                                : AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                      Obx(
                                        () => resend > 0
                                            ? Text(resend.toString())
                                            : InkWell(
                                                onTap: () async {
                                                  if (loading.value) return;
                                                  final sent =
                                                      await _submitMobile(
                                                        context,
                                                        reg ? 'reg' : 'login',
                                                        _mobilectl.text,
                                                      );
                                                  if (sent) _startResendTimer();
                                                },
                                                child: const Text(
                                                  'ارسال مجدد',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 15),
                          Obx(
                            () => authCode.isFalse
                                ? BTN(
                                    navigate: true,
                                    height: 50,
                                    onTap: () async {
                                      if (loading.value) return;
                                      _mobileF.unfocus();
                                      resend.value = 120;
                                      final sent = await _submitMobile(
                                        context,
                                        'login',
                                        _mobilectl.text,
                                      );
                                      if (!mounted) return;
                                      authCode.value = sent;
                                      if (sent) _startResendTimer();
                                    },
                                    name: 'تایید',
                                    inLoad: loading.value,
                                    textColor: Colors.white,
                                    icon: IconsaxPlusLinear.security_safe,
                                  )
                                : BTN(
                                    height: 50,
                                    onTap: () async {
                                      if (loading.value) return;
                                      var res = await _auth(
                                        _mobilectl.text,
                                        _codectl.text,
                                      );
                                      if (!mounted) return;
                                      if (res == true) {
                                        await _finished();
                                      } else if (res.toString() == 'false') {
                                        _codectl.clear();
                                      } else if (res == 'again') {
                                        _codectl.clear();
                                        _mobilectl.clear();
                                        authCode.value = false;
                                      }
                                    },
                                    inLoad: loading.value,
                                    name: 'ادامه',
                                    type: BTNType.ok,
                                  ),
                          ),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () {
                              MyBottomSheet.viewSupports(context);
                            },
                            child: Text(
                              'نیاز به پشتیبانی دارید؟',
                              style: TextStyle(
                                color: darkMode.value
                                    ? AppColors.primaryLite
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void checkMobile(BuildContext context, String mobile) {
    MyBottomSheet.view(
      context,
      child: (scrollController) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Flexible(
            flex: 2,
            child: BTN(
              name: 'تایید',
              type: BTNType.ok,
              onTap: () async {
                Get.back();
                await _submitMobile(context, 'login', mobile);
              },
            ),
          ),
          Flexible(
            child: BTN(
              name: 'ویرایش',
              type: BTNType.edit,
              onTap: () {
                Get.back();
                _mobileF.requestFocus();
              },
            ),
          ),
        ],
      ),
      isDismissible: false,
      title: '${_mobilectl.text} صحیح است؟',
      //h: 90
    );
  }
}

void showLoginConditions(BuildContext context) {
  MyBottomSheet.view(
    context,
    child: (scrollController) => SingleChildScrollView(
      controller: scrollController,
      child: const Column(
        children: [
          Text(
            'فعالیت«میک» مطابق با قوانین جمهوری اسلامی ایران، قانون تجارت الکترونیک و قانون حمایت از حقوق مصرف کننده بوده و کاربران آن نیز باید علاوه بر قوانین اختصاصی «میک» پیرو این قوانین نیز باشند.',
            textAlign: TextAlign.justify,
          ),
          SizedBox(height: 10),
          Text(
            'قوانین اختصاصی میک:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('''۱-مسئولیت تمام اطلاعات وارد شده در اپلیکیشن برعهده کاربر بوده و مسئولیت هرگونه اطلاعات نادرست با کاربر(فروشنده) می‌باشد.
          ۲-«میک» میتواند در صورت مشاهده هرگونه تخلف، عدم رعایت قوانین و یا سواستفاده از هر یک از خدمات پلتفرم از سمت کاربر بدون اطلاع قبلی، حساب کاربری فروشنده را بصورت دائم و یا موقت مسدود سازد. و در صورت نیاز به دستگاه‌های ذی‌ربط ارجاع دهد.
          ۳- مسئولیت قرار دادن اپلیکیشن و فروشگاه به شخص ثالث کاملا برعهده کاربر میباشد. 
          ۴- امکان ثبت و فروش محصولات غیرمجاز از جمله مشروبات الکلی، مواد مخدر، سلاح یا سایر اشیا و ادواتی که طبق قانون جمهوری اسلامی‌ ایران مجاز نیستند، در میک وجود ندارد.
          ۵- مسئولیت‌ کیفیت، قیمت، محتوا، شرایط و همچنین خدمات پس از فروش محصول بر عهده کاربر است.
          ۶- مسئولیت درج صحیح اطلاعات حساب بانکی برای فعال‌سازی میکیف و پرداخت آنلاین بر عهده کاربر بوده و عواقب ناشی از هرگونه مغایرت بر عهده‌ کاربر می‌باشد.
          ۷-استفاده از کیف پول و پرداخت هوشمند «میکیف» صرفا برای دریافت مبلغ سفارش کالا و یا خدماتی که مطابق قوانین جمهوری اسلامی ایران بوده مجاز می‌باشد.
          ۸- سامانه اطلاع‌رسانی میک(ارسال پیامک به مشتری) صرفا برای اطلاع وضعیت سفارش و یا کمپین‌های فروش به مشتریان قابل استفاده میباشد.
          ''', textAlign: TextAlign.justify),
          SizedBox(height: 20),
          Text(
            'سیاست حفظ حریم خصوصی',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('''حفظ اطلاعات و حریم شخصی کاربران و مشتریان آنها برای «میک» بسیار حائز اهمیت بوده و کلیه اطلاعات درج شده در پلتفرم «میک» کاملاً محرمانه و تنها در اختیار «میک»خواهد بود.
          برای استفاده از «میک» شماره همراه کاربر به عنوان شناسه یکتا دریافت و از این طریق برای احراز هویت و همچنین بازیابی اطلاعات در صورت نصب مجدد استفاده میشود.
          جهت تسهیل در امر خرید و فروش و احراز هویت کاربران، اطلاعاتی از قبیل نام، آدرس، شماره تلفن‌همراه و ایمیل از طرفین معامله دریافت و در اختیار فروشندگان گذاشته می‌شود.
          برای استفاده از خدمات کیف پول و پرداخت آنلاین بنا به شرایط و قوانین بانک مرکزی، شبکه شتاب و psp های همکار نیاز است تا کد ملی، شماره شبا و تصویر سلفی‌ حاوی دست‌نوشته قبول قوانین و کارت ملی را نیز بارگذاری کنید.
          ''', textAlign: TextAlign.justify),
          Text('تمامی اطلاعات شما بصورت امن نزد ما نگهداری خواهد شد.'),
          SizedBox(height: 20),
          Text(
            'ما همیشه همراه شما خواهیم بود.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
        ],
      ),
    ),

    // h: Get.height * 0.8,
    title: 'قوانین و مقررات استفاده از میک',
  );
}
