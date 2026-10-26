import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/loan.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/utils/fx/loans.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import '../reports/financial_screen.dart' show financialMoney;
import 'forms.dart' show loanMessage;

class LoanManagementForm extends StatefulWidget {
  final LoansFX fx;
  final String action;
  final String? loanId, installmentId, paymentId;
  const LoanManagementForm({
    required this.fx,
    required this.action,
    this.loanId,
    this.installmentId,
    this.paymentId,
    super.key,
  });
  @override
  State<LoanManagementForm> createState() => _LoanManagementFormState();
}

class _LoanManagementFormController extends GetxController {
  final date = TextEditingController(),
      amount = TextEditingController(),
      reason = TextEditingController();
  final confirmed = 'خیر'.obs, status = 'وصول'.obs;
  RemoteLoan? loan;
  List<LoanInstallment> schedule = [];
  LoanInstallment? installment;
  LoanPayment? payment;
  bool loading = true, saving = false;
  String? error;
}

class _LoanManagementFormState extends State<LoanManagementForm> {
  late final _page = _LoanManagementFormController();

  static const titles = {
    'reschedule': 'تغییر سررسید قسط',
    'waive': 'بخشودگی هزینه قسط',
    'reverse': 'برگشت بازپرداخت',
    'cheque': 'تعیین نتیجه چک وام',
  };
  static const statuses = {
    'وصول': 'CONFIRMED',
    'برگشت': 'BOUNCED',
    'عودت': 'RETURNED',
  };

  LoansFX get fx => widget.fx;
  bool get reschedule => widget.action == 'reschedule';
  bool get waive => widget.action == 'waive';
  bool get reverse => widget.action == 'reverse';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page.date.dispose();
    _page.amount.dispose();
    _page.reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.loan = null;
      _page.update();
    }
    try {
      await fx.authorize();
      await fx.restore();
      if (!titles.containsKey(widget.action) ||
          !fx.has(LoansFX.permissions[widget.action]!)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (fx.pending != null) {
        if (fx.pending!.action != widget.action) {
          throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
        }
        final snapshot = RemoteJson(fx.pending!.before);
        _page.loan = fx.parse(snapshot.value['loan']);
        _page.schedule = fx.installments(snapshot, _page.loan!.id);
        if (snapshot.value['payment'] != null) {
          _page.payment = LoanPayment(snapshot.value['payment']);
        }
      } else {
        final details = await fx.detail(widget.loanId!);
        _page.loan = details.loan;
        _page.schedule = details.installments;
        if (reschedule || waive) {
          _page.installment = _page.schedule
              .where((s) => s.id == widget.installmentId)
              .firstOrNull;
          if (_page.installment == null ||
              !(waive ? ['ACTIVE'] : ['DRAFT', 'ACTIVE']).contains(
                _page.loan!.status,
              )) {
            throw const AuthError(409, 'INVALID_STATE');
          }
        } else {
          _page.payment = (await fx.payments(_page.loan!.id))
              .where((p) => p.json['loanPaymentId'] == widget.paymentId)
              .firstOrNull;
          if (_page.payment == null ||
              (reverse
                  ? _page.payment!.json['status'] != 'CONFIRMED'
                  : _page.payment!.json['status'] != 'PENDING' ||
                        _page.payment!.json['method'] != 'CHEQUE')) {
            throw const AuthError(409, 'INVALID_STATE');
          }
          if (!reverse && !fx.access.has('accounting.cheque.clear')) {
            throw const AuthError(403, 'FORBIDDEN');
          }
        }
      }
    } catch (failure) {
      if (mounted) {
        _page.error = loanMessage(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  String selectedDate() {
    if (_page.date.text.isEmpty ||
        _page.date.text.trim().split(' ').length != 2) {
      throw const FormatException('تاریخ و ساعت واقعی را انتخاب کنید.');
    }
    final local = DateTime.parse(
      DateConvertor.jalaliToGrigori(_page.date.text),
    );
    // DateInput collects minute precision; do not insert the current second.
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    ).toUtc().toIso8601String();
  }

  Future<void> save() async {
    if (_page.loading ||
        _page.saving ||
        _page.error != null ||
        _page.loan == null)
      return;
    var attempted = false;
    try {
      var command = fx.pending;
      if (command == null) {
        final why = _page.reason.text.trim();
        if (why.isEmpty || why.length > 500) {
          throw const FormatException(
            'دلیل عملیات را وارد کنید (حداکثر ۵۰۰ کاراکتر).',
          );
        }
        final body = <String, dynamic>{'reason': why};
        if (reschedule || waive) {
          body.addAll({
            'loanId': _page.loan!.id,
            'expectedRevision': _page.loan!.revision,
          });
          if (reschedule) {
            final on = selectedDate();
            if (DateTime.parse(on).toUtc() ==
                DateTime.parse(_page.installment!.json['dueAt'] as String)
                    .toUtc()) {
              throw const FormatException('سررسید تغییر نکرده است.');
            }
            if (_page.loan!.json['fundedAt'] != null &&
                DateTime.parse(on).isBefore(
                  DateTime.parse(_page.loan!.json['fundedAt'] as String),
                )) {
              throw const FormatException(
                'سررسید نباید پیش از جابه‌جایی اصل وام باشد.',
              );
            }
            final ordered = [..._page.schedule]
              ..sort(
                (a, b) => (a.json['number'] as int).compareTo(
                  b.json['number'] as int,
                ),
              );
            DateTime? previous;
            for (final row in ordered) {
              final due = DateTime.parse(
                row.id == _page.installment!.id
                    ? on
                    : row.json['dueAt'] as String,
              );
              if (previous != null && due.isBefore(previous)) {
                throw const FormatException('ترتیب سررسید اقساط باید حفظ شود.');
              }
              previous = due;
            }
            body['installments'] = [
              {'loanInstallmentId': _page.installment!.id, 'dueAt': on},
            ];
          } else {
            final value = int.tryParse(
              _page.amount.text
                  .toEnglishDigit()
                  .replaceAll(',', '')
                  .replaceAll('٬', '')
                  .trim(),
            );
            final available =
                _page.installment!.money('chargeAmount') -
                _page.installment!.money('waivedChargeAmount') -
                _page.installment!.money('paidChargeAmount') -
                _page.installment!.money('pendingChargeAmount');
            if (_page.confirmed.value != 'بله' ||
                value == null ||
                value <= 0 ||
                value > available) {
              throw const FormatException(
                'توافق واقعی و مبلغ بخشودگی را بررسی کنید؛ مبالغ پرداخت‌شده یا رزروشده قابل بخشودگی نیستند.',
              );
            }
            body.addAll({
              'loanInstallmentId': _page.installment!.id,
              'amount': value,
              'agreementConfirmed': true,
            });
          }
        } else {
          if (_page.confirmed.value != 'بله') {
            throw const FormatException(
              'وقوع واقعی نتیجه چک یا برگشت وجه را تأیید کنید.',
            );
          }
          body.addAll({
            'loanPaymentId': _page.payment!.json['loanPaymentId'],
            'expectedRevision': _page.payment!.json['revision'],
          });
          if (reverse) {
            body['fundsConfirmed'] = true;
          } else {
            final on = selectedDate();
            if (DateTime.parse(on).isAfter(DateTime.now().toUtc()) ||
                DateTime.parse(on).isBefore(
                  DateTime.parse(_page.payment!.json['occurredAt'] as String),
                )) {
              throw const FormatException(
                'زمان نتیجه نباید آینده یا قبل از ثبت چک باشد.',
              );
            }
            body.addAll({
              'status': statuses[_page.status.value],
              'confirmed': true,
              'occurredAt': on,
            });
          }
        }
        command = LoanCommand(
          widget.action,
          body,
          before: {
            'loan': _page.loan!.json,
            'installments': _page.schedule.map((s) => s.json).toList(),
            if (_page.payment != null) 'payment': _page.payment!.json,
          },
        );
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      await fx.send(command);
      if (mounted) {
        Alert.success('عملیات وام با موفقیت ثبت شد.');
        Get.back(result: true);
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          !attempted && failure is FormatException
              ? failure.message
              : loanMessage(failure),
          context: context,
        );
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
  ) => GetBuilder<_LoanManagementFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: titles[widget.action] ?? 'عملیات وام',
        ),
        child: (_) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_page.loading || _page.saving) const Loader(),
            if (_page.error != null) Text(_page.error!),
            if (_page.loan != null && _page.error == null) ...[
              Text(_page.loan!.json['name'] as String),
              MyDivider(),
              if (_page.payment != null) ...[
                Text(
                  'مبلغ بازپرداخت: ${financialMoney(_page.payment!.money('amount'))}',
                ),
                if (_page.payment!.json['cheque'] != null)
                  Text(
                    'چک ${RemoteJson(_page.payment!.json['cheque']).text('number')} — ${RemoteJson(_page.payment!.json['cheque']).text('bankName')}',
                  ),
              ],
              if (fx.pending != null) ...[
                const Text(
                  'همان درخواست قبلی پیگیری می‌شود؛ وجه را دوباره جابه‌جا نکنید.',
                ),
                Text('دلیل: ${fx.pending!.body['reason']}'),
              ] else ...[
                if (_page.installment != null)
                  Text(
                    'قسط ${_page.installment!.json['number']} — سررسید فعلی: ${DateConvertor.grigoriToJalali(_page.installment!.json['dueAt'] as String)}',
                  ),
                if (reschedule) ...[
                  const Text(
                    'تغییر سررسید، مبالغ و هزینه‌های شناسایی‌شده قبلی را تغییر نمی‌دهد.',
                  ),
                  DateInput(
                    controller: _page.date,
                    name: 'سررسید جدید',
                    require: true,
                    timePicker: true,
                    enabled: !_page.saving,
                    onChanged: (_) {},
                  ),
                ] else if (waive) ...[
                  const Text(
                    'فقط هزینه/درآمد مالیِ پرداخت‌نشده و رزرو‌نشده قابل بخشودگی است؛ اصل وام تغییر نمی‌کند.',
                  ),
                  PriceInput(
                    controller: _page.amount,
                    name: 'مبلغ بخشودگی',
                    require: true,
                    readOnly: _page.saving,
                  ),
                  const Text(
                    'توافق واقعی طرف قرارداد برای بخشودگی انجام شده است.',
                  ),
                ] else if (reverse)
                  const Text(
                    'وجه واقعاً در جهت عکس جابه‌جا شده است. پرداخت اصلی حذف نمی‌شود و مانده اقساط باز می‌شود.',
                  )
                else ...[
                  MyTab(
                    tab: statuses.keys.toList(),
                    value: _page.status,
                    callback: (v) {
                      if (!_page.saving) {
                        {
                          _page.status.value = v;
                          _page.confirmed.value = 'خیر';
                          _page.update();
                        }
                      }
                    },
                  ),
                  DateInput(
                    controller: _page.date,
                    name: 'زمان واقعی نتیجه چک',
                    require: true,
                    timePicker: true,
                    enabled: !_page.saving,
                    onChanged: (_) => _page.confirmed.value = 'خیر',
                  ),
                  const Text(
                    'وصول، بازپرداخت را قطعی می‌کند؛ برگشت و عودت، مبلغ رزروشده را آزاد می‌کنند.',
                  ),
                ],
                Input(
                  controller: _page.reason,
                  name: 'دلیل عملیات',
                  require: true,
                  maxLength: 500,
                  readOnly: _page.saving,
                ),
                if (!reschedule) ...[
                  if (!waive) const Text('وقوع واقعی عملیات را تأیید می‌کنم.'),
                  MyTab(
                    tab: ['خیر', 'بله'],
                    value: _page.confirmed,
                    callback: (v) {
                      if (!_page.saving) {
                        _page.confirmed.value = v;
                        _page.update();
                      }
                    },
                  ),
                ],
              ],
              BTN(
                key: const ValueKey('loan-management-save'),
                name: fx.pending == null ? 'ثبت نهایی' : 'پیگیری ثبت قبلی',
                disabled: _page.loading || _page.saving,
                onTap: save,
              ),
            ],
            BTN(
              name: 'دریافت مجدد اطلاعات',
              disabled: _page.loading || _page.saving,
              onTap: load,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildLoanManagementFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return LoanManagementForm(
    fx: args.required<LoansFX>('fx'),
    action: args.required<String>('action'),
    loanId: args.optional<String>('loanId'),
    installmentId: args.optional<String>('installmentId'),
    paymentId: args.optional<String>('paymentId'),
  );
}
