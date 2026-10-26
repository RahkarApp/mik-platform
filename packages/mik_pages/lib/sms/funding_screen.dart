import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/business_sms.dart';
import 'package:mik_data/utils/fx/business_sms.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_data/utils/fx/sms_funding.dart';
import 'package:mik_utils/public/price.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsFundingScreen extends StatefulWidget {
  final BusinessSmsFX sms;
  const SmsFundingScreen({required this.sms, super.key});
  @override
  State<SmsFundingScreen> createState() => _SmsFundingScreenState();
}

class _SmsFundingScreenController extends GetxController {
  _SmsFundingScreenController(this.widget);
  SmsFundingScreen widget;
  late final fx = SmsFundingFX(widget.sms);
  final amount = TextEditingController();
  SmsWallet? wallet, sales;
  SmsTopupPayment? payment;
  RealtimeWatch? realtime;
  bool loading = true, saving = false;
  int generation = 0;
  String? error;
}

class _SmsFundingScreenState extends State<SmsFundingScreen>
    with WidgetsBindingObserver {
  late final _page = _SmsFundingScreenController(widget);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _page.realtime = RealtimeWatch(
      RealtimeFX.forContext(widget.sms.context),
      {'payment.payment', 'wallet.account', 'wallet.sales-account'},
      () => load(background: true),
      busy: () => _page.loading || _page.saving,
      invalidate: () {
        if (mounted) {
          {
            _page.generation++;
            _page.loading = false;
            _page.wallet = null;
            _page.sales = null;
            _page.payment = null;
            _page.update();
          }
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page.generation++;
    WidgetsBinding.instance.removeObserver(this);
    _page.realtime?.dispose();
    _page.amount.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_page.loading && !_page.saving)
      load();
  }

  Future<void> load({bool background = false}) async {
    if (!mounted) return;
    final request = ++_page.generation;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      _page.update();
    }
    try {
      await widget.sms.authorize();
      await _page.fx.restore();
      final balance = widget.sms.has('balance.read')
          ? await widget.sms.wallet()
          : null;
      final source =
          widget.sms.has('balance.read') && widget.sms.has('balance.transfer')
          ? await _page.fx.sales()
          : null;
      final command = _page.fx.pending;
      SmsTopupPayment? current;
      // Merely opening/resuming this page performs GETs, never repeats an unknown financial mutation.
      if (command?.kind == 'TOPUP' &&
          command?.paymentId != null &&
          _page.fx.canReadPayment) {
        current = await _page.fx.payment(
          command!.paymentId!,
          amount: command.body['amount'] as int,
        );
      }
      if (mounted && request == _page.generation) {
        {
          _page.wallet = balance;
          _page.sales = source;
          _page.payment = current ?? _page.payment;
          _page.update();
        }
      }
    } catch (e) {
      if (mounted && request == _page.generation) {
        {
          _page.error = SmsFundingFX.message(e);
          _page.update();
        }
        Alert.error(_page.error!);
      }
    } finally {
      if (mounted && request == _page.generation) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  int readAmount() {
    final text = _page.amount.text
        .toEnglishDigit()
        .replaceAll(RegExp(r'[,٬\s]'), '')
        .replaceAll('تومان', '')
        .replaceAll('ریال', '');
    final value = RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;
    if (value == null || value < 1 || value > 1000000000000) {
      throw const AuthError(400, 'VALIDATION_FAILED');
    }
    return value;
  }

  Future<void> submit(String kind) async {
    if (_page.loading || _page.saving) return;
    try {
      if (_page.fx.pending != null) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      final value = readAmount();
      if (kind == 'TOPUP' && SmsFundingFX.returnUrl.isEmpty) {
        Alert.error(
          'شارژ آنلاین هنوز فعال نشده است؛ نشانی بازگشت پرداخت باید هنگام راه‌اندازی تنظیم شود.',
        );
        return;
      }
      if (kind == 'TRANSFER' &&
          _page.sales != null &&
          value > _page.sales!.available) {
        throw const AuthError(409, 'INSUFFICIENT_CREDIT');
      }
      final command = SmsFundingCommand(
        kind,
        kind == 'TRANSFER'
            ? {'amount': value}
            : {
                'purpose': 'SMS_TOPUP',
                'amount': value,
                'returnUrl': SmsFundingFX.returnUrl,
              },
      );
      await perform(command);
    } catch (e) {
      if (mounted) Alert.error(SmsFundingFX.message(e));
    }
  }

  Future<void> perform(SmsFundingCommand command) async {
    if (_page.saving) return;
    {
      _page.saving = true;
      _page.update();
    }
    try {
      final result = await _page.fx.send(command);
      if (!mounted) return;
      if (result is SmsWallet) {
        {
          _page.wallet = result;
          _page.update();
        }
        _page.amount.clear();
        Alert.success('اعتبار از کیف فروش به کیف پیامک منتقل شد.');
      } else if (result is SmsTopupPayment) {
        {
          _page.payment = result;
          _page.update();
        }
        if (result.applied) {
          _page.amount.clear();
          Alert.success(result.description);
        } else if (result.status == 'FAILED' ||
            result.status == 'ACTION_REQUIRED' ||
            result.fulfillment == 'ACTION_REQUIRED') {
          Alert.error(result.description);
        } else {
          Alert.info(result.description);
        }
      }
      await load();
    } catch (e) {
      if (mounted) Alert.error(SmsFundingFX.message(e));
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  Future<void> openBank() async {
    final current = _page.payment;
    if (current == null ||
        current.status != 'PENDING' ||
        current.row.optionalText('paymentUrl') == null) {
      return;
    }
    if (!DateTime.parse(current.row.text('expiresAt'))
        .isAfter(DateTime.now().toUtc())) {
      Alert.error('مهلت این لینک تمام شده است؛ وضعیت پرداخت را پیگیری کنید.');
      return;
    }
    try {
      if (!await launchUrl(
        Uri.parse(current.row.text('paymentUrl')),
        mode: LaunchMode.externalApplication,
      )) {
        Alert.error('باز کردن صفحه بانک انجام نشد؛ دوباره تلاش کنید.');
      }
    } catch (_) {
      Alert.error('باز کردن صفحه بانک انجام نشد؛ دوباره تلاش کنید.');
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_SmsFundingScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => true,
      header: Header.page(context, text: 'افزایش اعتبار پیامک'),
      child: (_) => SingleChildScrollView(
        child: Column(
          children: [
            MyDivider(text: 'اعتبار قابل استفاده'),
            Text(
              _page.wallet == null
                  ? 'پیامک: —'
                  : 'پیامک: ${Price.show(_page.wallet!.available)} تومان',
            ),
            if (widget.sms.has('balance.transfer'))
              Text(
                _page.sales == null
                    ? 'کیف فروش: —'
                    : 'کیف فروش: ${Price.show(_page.sales!.available)} تومان',
              ),
            if (_page.error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_page.error!),
              ),
            if (_page.fx.pending == null) ...[
              PriceInput(
                controller: _page.amount,
                name: 'میزان افزایش اعتبار',
                enabled: !_page.loading && !_page.saving,
                require: true,
              ),
              if (_page.fx.canTopup && _page.fx.canReadPayment)
                BTN(
                  name: 'شارژ آنلاین',
                  type: BTNType.ok,
                  disabled: _page.loading || _page.saving,
                  onTap: () => submit('TOPUP'),
                ),
              if (!_page.loading &&
                  _page.fx.canTopup &&
                  !_page.fx.canReadPayment)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'برای شارژ آنلاین، مجوز پیگیری پرداخت هم لازم است.',
                  ),
                ),
              if (widget.sms.has('balance.transfer'))
                BTN(
                  name: 'انتقال از کیف فروش',
                  disabled: _page.loading || _page.saving,
                  onTap: () => submit('TRANSFER'),
                ),
              if (!_page.loading &&
                  !_page.fx.canTopup &&
                  !widget.sms.has('balance.transfer'))
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('مجوز افزایش اعتبار پیامک را ندارید.'),
                ),
            ],
            if (_page.fx.pending != null) ...[
              MyDivider(text: 'پیگیری عملیات قبلی'),
              Text(
                'مبلغ: ${Price.show(_page.fx.pending!.body['amount'])} تومان',
              ),
              BTN(
                name: _page.fx.pending!.kind == 'TRANSFER'
                    ? 'پیگیری انتقال اعتبار'
                    : 'پیگیری پرداخت',
                disabled: _page.loading || _page.saving,
                onTap: () => perform(_page.fx.pending!),
              ),
            ],
            if (_page.payment != null) ...[
              MyDivider(text: 'وضعیت پرداخت'),
              Text(_page.payment!.description),
              if (_page.payment!.row.optionalText('referenceNo')
                  case final reference?)
                Text('شماره پیگیری: $reference'),
              if (_page.payment!.status == 'PENDING' &&
                  _page.payment!.row.optionalText('paymentUrl') != null)
                BTN(
                  name: 'ورود به درگاه پرداخت',
                  navigate: true,
                  disabled: _page.loading || _page.saving,
                  onTap: openBank,
                ),
            ],
            BTN(
              name: 'دریافت مجدد',
              icon: IconsaxPlusLinear.refresh_2,
              disabled: _page.loading || _page.saving,
              onTap: load,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant SmsFundingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

Widget buildSmsFundingRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return SmsFundingScreen(sms: args.required<BusinessSmsFX>('sms'));
}
