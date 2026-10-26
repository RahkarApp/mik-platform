import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_amounts.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/invoice_payment.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';

class PartyPaymentScreen extends StatefulWidget {
  final String appId, partyType, partyId;
  const PartyPaymentScreen({
    required this.appId,
    required this.partyType,
    required this.partyId,
    super.key,
  });
  @override
  State<PartyPaymentScreen> createState() => _PartyPaymentScreenState();
}

class _PartyPaymentScreenController extends GetxController {
  InvoicePaymentFX? fx;
  final method = 'نقدی'.obs, confirmed = 'بله'.obs;
  final amount = TextEditingController(),
      reference = TextEditingController(),
      note = TextEditingController();
  List<SalePaymentTarget> targets = [];
  String? targetId, error;
  bool loading = false, saving = false;
}

class _PartyPaymentScreenState extends State<PartyPaymentScreen> {
  late final _page = _PartyPaymentScreenController();

  static const methods = {
    'نقدی': 'CASH',
    'کارت': 'CARD',
    'انتقال بانکی': 'BANK_TRANSFER',
  };

  bool get locked =>
      _page.loading ||
      _page.saving ||
      _page.error != null ||
      _page.fx?.pending != null;
  bool get incoming => widget.partyType == 'CUSTOMER';
  String get title => incoming ? 'ثبت دریافت وجه' : 'ثبت پرداخت وجه';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    _page.amount.dispose();
    _page.reference.dispose();
    _page.note.dispose();
    _page.method.close();
    _page.confirmed.close();
    super.dispose();
  }

  Future<void> load() async {
    if (_page.loading || _page.saving) return;
    {
      _page.loading = true;
      _page.error = null;
      _page.targets = [];
      _page.targetId = null;
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= InvoicePaymentFX.forParty(
        active,
        widget.partyType,
        widget.partyId,
      );
      await _page.fx!.authorize();
      await _page.fx!.restore();
      // A saved command must be retried unchanged, even if options have changed.
      final rows = _page.fx!.pending == null
          ? await _page.fx!.targets(methods[_page.method.value]!)
          : <SalePaymentTarget>[];
      if (!mounted) return;
      {
        _page.targets = rows;
        _page.update();
      }
    } catch (failure) {
      if (!mounted) return;
      {
        _page.error = FinancialReportsFX.message(failure);
        _page.update();
      }
      Alert.error(_page.error!, context: context);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> create() async {
    if (locked) return;
    try {
      final value = InvoiceAmounts.parse(_page.amount.text);
      final target = _page.targets
          .where((row) => row.id == _page.targetId)
          .firstOrNull;
      final ref = _page.reference.text.trim(), text = _page.note.text.trim();
      if (value <= 0 || target == null || _page.confirmed.value != 'بله') {
        Alert.error(
          'مبلغ مثبت و حساب مبدأ یا مقصد لازم است.',
          context: context,
        );
        return;
      }
      if (ref.length > 200 ||
          text.length > 1000 ||
          RegExp(r'[\u0000-\u0008]').hasMatch('$ref$text')) {
        throw const FormatException('Invalid payment details');
      }
      await send(
        InvoicePaymentCommand('PAYMENT', {
          'partyType': widget.partyType,
          'partyId': widget.partyId,
          'payment': {
            'amount': value,
            'method': methods[_page.method.value],
            'direction': incoming ? 'IN' : 'OUT',
            'confirmed': true,
            'routing': target.routing,
            if (ref.isNotEmpty) 'transactionReference': ref,
            if (text.isNotEmpty) 'note': text,
          },
        }),
      );
    } catch (failure) {
      if (mounted) {
        Alert.error(FinancialReportsFX.message(failure), context: context);
      }
    }
  }

  Future<void> send(InvoicePaymentCommand command) async {
    if (_page.saving || _page.loading) return;
    {
      _page.saving = true;
      _page.update();
    }
    try {
      await _page.fx!.send(command);
      if (!mounted) return;
      Alert.success(
        incoming
            ? 'دریافت وجه با موفقیت ثبت شد.'
            : 'پرداخت وجه با موفقیت ثبت شد.',
      );
      Get.back(result: true);
    } catch (failure) {
      if (mounted) {
        Alert.error(FinancialReportsFX.message(failure), context: context);
      }
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_PartyPaymentScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: title),
        child: (_) => ListView(
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null) Text(_page.error!),
            if (_page.error != null)
              MiniBTN(
                noFlex: true,
                icon: IconsaxPlusLinear.refresh,
                name: 'تلاش مجدد',
                onTap: load,
              ),
            const Text(
              'این عملیات وجه را از بانک جابه‌جا نمی‌کند؛ فقط دریافت یا پرداخت انجام‌شده را ثبت کنید.',
            ),
            const Text(
              'سرور طبق سیاست تخصیص کسب‌وکار، وجه را به فاکتورهای مجاز تخصیص می‌دهد. اعتبار باقی‌مانده در گردش حساب دیده می‌شود؛ تخصیص دستی از بخش پرداخت فاکتور انجام می‌شود.',
            ),
            MyDivider(text: incoming ? 'روش دریافت' : 'روش پرداخت'),
            if (_page.fx?.pending case final command?) ...[
              const Text(
                'نتیجه ثبت قبلی هنوز تأیید نشده است. برای جلوگیری از ثبت تکراری، همان درخواست را پیگیری کنید.',
              ),
              Text(
                'مبلغ درخواست: ${(command.body['payment'] as Map)['amount']} تومان',
              ),
              BTN(
                name: 'پیگیری ثبت وجه',
                disabled: _page.loading || _page.saving || _page.error != null,
                onTap: () => send(command),
              ),
            ] else ...[
              IgnorePointer(
                ignoring: locked,
                child: MyTab(
                  tab: methods.keys.toList(),
                  value: _page.method,
                  callback: (String value) {
                    _page.method.value = value;
                    _page.confirmed.value = 'بله';
                    load();
                  },
                ),
              ),
              MyDivider(text: incoming ? 'حساب دریافت وجه' : 'حساب پرداخت وجه'),
              if (!_page.loading &&
                  _page.error == null &&
                  _page.targets.isEmpty)
                const Text(
                  'حساب یا صندوق مجازی دریافت نشد. حساب‌ها و مجوز استفاده را بررسی کنید.',
                ),
              for (final target in _page.targets)
                MiniBTN(
                  noFlex: true,
                  icon: IconsaxPlusLinear.tick_circle,
                  name:
                      '${_page.targetId == target.id ? '✓ ' : ''}${target.name}',
                  onTap: locked
                      ? null
                      : () {
                          _page.targetId = target.id;
                          _page.update();
                        },
                ),
              PriceInput(
                key: const ValueKey('party-payment-amount'),
                controller: _page.amount,
                name: 'مبلغ',
                currency: 'تومان',
                require: true,
                readOnly: locked,
              ),
              Input(
                controller: _page.reference,
                name: 'شماره پیگیری',
                maxLength: 200,
                readOnly: locked,
              ),
              Input(
                controller: _page.note,
                name: 'توضیحات',
                maxLength: 1000,
                readOnly: locked,
              ),
              BTN(name: title, disabled: locked, onTap: create),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildPartyPaymentRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return PartyPaymentScreen(
    appId: args.required<String>('appId'),
    partyType: args.required<String>('partyType'),
    partyId: args.required<String>('partyId'),
  );
}
