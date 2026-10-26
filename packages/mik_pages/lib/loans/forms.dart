import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/bankInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/loan.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/loans.dart';
import 'package:mik_data/utils/fx/partner_movements.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import '../reports/financial_screen.dart' show financialMoney;

String loanMessage(Object failure) {
  if (failure is FormatException) {
    return 'پاسخ وام معتبر نیست؛ اطلاعات را تازه یا ثبت قبلی را پیگیری کنید.';
  }
  if (failure is AuthError) {
    if (failure.code == 'FORBIDDEN') {
      return 'مجوز عملیات وام یا استفاده از صندوق و حساب انتخاب‌شده را ندارید.';
    }
    if (failure.code == 'IDEMPOTENCY_CONFLICT') {
      return 'ابتدا ثبت قبلی وام را پیگیری کنید.';
    }
    if (failure.code == 'REVISION_CONFLICT') {
      return 'اطلاعات وام تغییر کرده است؛ اطلاعات را تازه کنید.';
    }
    if (failure.code == 'INVALID_STATE') {
      return 'وضعیت وام برای این عملیات مناسب نیست.';
    }
    if (failure.code == 'SETTLEMENT_EXCEEDED') {
      return 'مبلغ از مانده قابل بازپرداخت اقساط بیشتر است یا با چک پوشش داده شده است.';
    }
  }
  return SaleInvoiceFX.message(failure);
}

class _InstallmentInputs {
  final date = TextEditingController(),
      principal = TextEditingController(),
      charge = TextEditingController(text: '0');
  void dispose() {
    date.dispose();
    principal.dispose();
    charge.dispose();
  }
}

class _RepaymentInputs {
  final principal = TextEditingController(text: '0'),
      charge = TextEditingController(text: '0');
  void dispose() {
    principal.dispose();
    charge.dispose();
  }
}

class LoanForm extends StatefulWidget {
  final LoansFX fx;
  final String action;
  final String? loanId;
  const LoanForm({
    required this.fx,
    this.action = 'create',
    this.loanId,
    super.key,
  });
  @override
  State<LoanForm> createState() => _LoanFormState();
}

class _LoanFormController extends GetxController {
  final name = TextEditingController(),
      party = TextEditingController(),
      phone = TextEditingController(),
      reference = TextEditingController(),
      principal = TextEditingController(),
      charge = TextEditingController(text: '0'),
      note = TextEditingController(),
      date = TextEditingController(),
      amount = TextEditingController(),
      reason = TextEditingController();
  final bank = TextEditingController(),
      chequeNumber = TextEditingController(),
      sayad = TextEditingController(),
      drawer = TextEditingController(),
      chequeDue = TextEditingController();
  final rows = [_InstallmentInputs()];
  final repayment = <String, _RepaymentInputs>{};
  final allocationMode = 'خودکار'.obs, futureCharges = 'خیر'.obs;
  final direction = 'وام دریافتی'.obs,
      method = 'نقدی'.obs,
      confirmed = 'بله'.obs;
  RemoteLoan? loan;
  List<LoanInstallment> schedule = [];
  List<SalePaymentTarget> targets = [];
  List<RemoteSupplier> partners = [];
  String? fundId, partnerId, error;
  bool loading = true, saving = false, targetsLoading = false;
  String text(TextEditingController c, int max, {bool required = false}) {
    final value = c.text.trim();
    if (required && value.isEmpty || value.length > max) {
      throw const FormatException('فیلدهای الزامی و طول متن‌ها را بررسی کنید.');
    }
    return value;
  }
}

class _LoanFormState extends State<LoanForm> {
  late final _page = _LoanFormController();

  LoansFX get fx => widget.fx;
  bool get busy => _page.loading || _page.saving || _page.targetsLoading;
  bool get create => widget.action == 'create';
  bool get fund => widget.action == 'fund';
  bool get pay => widget.action == 'payment';
  String get methodCode => _page.method.value == 'نقدی'
      ? 'CASH'
      : _page.method.value == 'چک'
      ? 'CHEQUE'
      : 'BANK_TRANSFER';
  String get title => create
      ? 'وام جدید'
      : fund
      ? 'ثبت جابه‌جایی اصل وام'
      : pay
      ? 'ثبت بازپرداخت وام'
      : 'لغو پیش‌نویس وام';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _page.bank,
      _page.chequeNumber,
      _page.sayad,
      _page.drawer,
      _page.chequeDue,
      _page.name,
      _page.party,
      _page.phone,
      _page.reference,
      _page.principal,
      _page.charge,
      _page.note,
      _page.date,
      _page.amount,
      _page.reason,
    ]) {
      c.dispose();
    }
    for (final r in _page.rows) {
      r.dispose();
    }
    for (final r in _page.repayment.values) {
      r.dispose();
    }
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
      for (final r in _page.repayment.values) {
        r.dispose();
      }
      _page.repayment.clear();
      await fx.authorize();
      await fx.restore();
      if (fx.pending != null) {
        if (fx.pending!.action != widget.action) {
          throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
        }
        if (fx.pending!.before != null) {
          final snapshot = RemoteJson(fx.pending!.before);
          _page.loan = fx.parse(snapshot.value['loan']);
          _page.schedule = fx.installments(snapshot, _page.loan!.id);
        }
      } else {
        final permission = LoansFX.permissions[widget.action];
        if (permission == null || !fx.has(permission)) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        if (!create) {
          final detail = await fx.detail(widget.loanId!);
          _page.loan = detail.loan;
          _page.schedule = detail.installments;
          if (pay) {
            for (final row in _page.schedule) {
              _page.repayment[row.id] = _RepaymentInputs();
            }
          }
          if (_page.loan!.status != (pay ? 'ACTIVE' : 'DRAFT')) {
            throw const AuthError(409, 'INVALID_STATE');
          }
        } else if (fx.access.has('accounting.partner.read', business: true)) {
          final partnerFX = PartnerMovementsFX(fx.context);
          await partnerFX.authorize();
          _page.partners = (await partnerFX.partners())
              .where((p) => p.status == 'ACTIVE')
              .toList();
        }
        if (fund || pay) _page.targets = await fx.targets(methodCode);
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

  Future<void> loadTargets(String value) async {
    if (busy) return;
    {
      _page.targetsLoading = true;
      _page.method.value = value;
      _page.targets = [];
      _page.fundId = null;
      _page.update();
    }
    try {
      final result = await fx.targets(methodCode);
      if (mounted) {
        _page.targets = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted) Alert.error(loanMessage(failure), context: context);
    } finally {
      if (mounted) {
        _page.targetsLoading = false;
        _page.update();
      }
    }
  }

  int money(TextEditingController c, {bool positive = false}) {
    final value = int.tryParse(
      c.text
          .toEnglishDigit()
          .replaceAll(',', '')
          .replaceAll('٬', '')
          .replaceAll('تومان', '')
          .replaceAll('ریال', '')
          .trim(),
    );
    if (value == null ||
        value < (positive ? 1 : 0) ||
        value > 9007199254740991) {
      throw const FormatException(
        'مبلغ صحیح به تومان وارد کنید؛ برای مبلغ بدون هزینه، صفر وارد کنید.',
      );
    }
    return value;
  }

  String on(TextEditingController c) {
    if (c.text.isEmpty) throw const FormatException('تاریخ را وارد کنید.');
    final converted = DateTime.parse(DateConvertor.jalaliToGrigori(c.text));
    if (c.text.trim().split(' ').length == 2) {
      return DateTime(
        converted.year,
        converted.month,
        converted.day,
        converted.hour,
        converted.minute,
      ).toUtc().toIso8601String();
    }
    final day = converted.toIso8601String().substring(0, 10);
    return '${day}T00:00:00.000Z';
  }

  Future<void> save() async {
    if (busy || _page.error != null) return;
    var attempted = false;
    try {
      var command = fx.pending;
      if (command == null) {
        final body = <String, dynamic>{};
        if (create) {
          final counterparty = <String, dynamic>{
            'name': _page.text(_page.party, 200, required: true),
          };
          if (_page.phone.text.trim().isNotEmpty) {
            counterparty['phone'] = _page.text(_page.phone, 100);
          }
          if (_page.reference.text.trim().isNotEmpty) {
            counterparty['reference'] = _page.text(_page.reference, 100);
          }
          body.addAll({
            'name': _page.text(_page.name, 200, required: true),
            'direction': _page.direction.value == 'وام دریافتی'
                ? 'RECEIVED'
                : 'GRANTED',
            'counterparty': counterparty,
            'principalAmount': money(_page.principal, positive: true),
            'contractChargeAmount': money(_page.charge),
            'installments': [
              for (final row in _page.rows)
                {
                  'dueAt': on(row.date),
                  'principalAmount': money(row.principal),
                  'chargeAmount': money(row.charge),
                },
            ],
            if (_page.partnerId != null) 'partnerId': _page.partnerId,
            if (_page.note.text.trim().isNotEmpty)
              'note': _page.text(_page.note, 1000),
          });
          final installments = body['installments'] as List;
          var p = 0, c = 0;
          DateTime? previous;
          for (final row in installments) {
            final due = DateTime.parse(row['dueAt'] as String);
            if ((row['principalAmount'] as int) +
                        (row['chargeAmount'] as int) <=
                    0 ||
                previous != null && due.isBefore(previous)) {
              throw const FormatException(
                'اقساط باید مبلغ مثبت و سررسید مرتب داشته باشند.',
              );
            }
            previous = due;
            p += row['principalAmount'] as int;
            c += row['chargeAmount'] as int;
          }
          if (p != body['principalAmount'] ||
              c != body['contractChargeAmount']) {
            throw const FormatException(
              'جمع اصل و هزینه اقساط باید دقیقاً با قرارداد برابر باشد.',
            );
          }
        } else {
          body.addAll({
            'loanId': _page.loan!.id,
            'expectedRevision': _page.loan!.revision,
          });
          if (!pay)
            body['reason'] = _page.text(_page.reason, 500, required: true);
          if (fund || pay) {
            if (_page.confirmed.value != 'بله' ||
                !_page.targets.any(
                  (t) =>
                      t.id == _page.fundId &&
                      t.accepts(
                        methodCode == 'CHEQUE' ? 'BANK_TRANSFER' : methodCode,
                      ),
                )) {
              throw const FormatException(
                'صندوق یا حساب معتبر را انتخاب کنید.',
              );
            }
            final at = on(_page.date);
            if (DateTime.parse(at).isAfter(DateTime.now().toUtc())) {
              throw const FormatException('تاریخ نباید آینده باشد.');
            }
            if (fund &&
                _page.schedule.any(
                  (s) =>
                      DateTime.parse(s.json['dueAt'] as String)
                          .isBefore(DateTime.parse(at)),
                )) {
              throw const FormatException(
                'تاریخ جابه‌جایی اصل پول نباید پس از سررسید هیچ قسطی باشد.',
              );
            }
            if (pay &&
                DateTime.parse(at).isBefore(
                  DateTime.parse(_page.loan!.json['fundedAt'] as String),
                )) {
              throw const FormatException(
                'بازپرداخت نمی‌تواند پیش از دریافت یا پرداخت اصل وام باشد.',
              );
            }
            body['occurredAt'] = at;
            if (fund) {
              body.addAll({
                'method': methodCode,
                'routing': {'fundId': _page.fundId},
                'fundsConfirmed': true,
                if (_page.reference.text.trim().isNotEmpty)
                  'reference': _page.text(_page.reference, 200),
              });
            } else {
              body['payment'] = {
                'amount': money(_page.amount, positive: true),
                'method': methodCode,
                'routing': {'fundId': _page.fundId},
                'confirmed': true,
                if (_page.reference.text.trim().isNotEmpty)
                  'transactionReference': _page.text(_page.reference, 200),
                if (_page.note.text.trim().isNotEmpty)
                  'note': _page.text(_page.note, 1000),
              };
              if (_page.allocationMode.value == 'انتخاب اقساط') {
                final parts = <Map<String, dynamic>>[];
                var total = 0;
                for (final row in _page.schedule) {
                  final inputs = _page.repayment[row.id]!;
                  final p = money(inputs.principal), c = money(inputs.charge);
                  if (p + c == 0) continue;
                  if (p > remaining(row, false) || c > remaining(row, true)) {
                    throw const FormatException(
                      'مبلغ انتخابی از مانده آزاد قسط بیشتر است.',
                    );
                  }
                  if (c > recognized(row) &&
                      _page.futureCharges.value != 'بله') {
                    throw const FormatException(
                      'شناسایی هزینه آینده را صریحاً تأیید کنید.',
                    );
                  }
                  parts.add({
                    'loanInstallmentId': row.id,
                    'principalAmount': p,
                    'chargeAmount': c,
                  });
                  total += p + c;
                }
                if (parts.isEmpty ||
                    total != money(_page.amount, positive: true)) {
                  throw const FormatException(
                    'جمع اصل و هزینه انتخابی باید با مبلغ بازپرداخت برابر باشد.',
                  );
                }
                body['allocations'] = parts;
                body['recognizeFutureCharges'] =
                    _page.futureCharges.value == 'بله';
              }
              if (methodCode == 'CHEQUE') {
                final cheque = <String, dynamic>{
                  'bankName': _page.text(_page.bank, 100, required: true),
                  'number': _page.text(_page.chequeNumber, 64, required: true),
                  'dueAt': on(_page.chequeDue),
                };
                if (_page.sayad.text.trim().isNotEmpty) {
                  final value = _page.sayad.text.trim().toEnglishDigit();
                  if (!RegExp(r'^\d{16}$').hasMatch(value)) {
                    throw const FormatException('شناسه صیاد باید ۱۶ رقم باشد.');
                  }
                  cheque['sayadId'] = value;
                }
                if (_page.drawer.text.trim().isNotEmpty) {
                  cheque['drawerName'] = _page.text(_page.drawer, 200);
                }
                (body['payment'] as Map<String, dynamic>)['cheque'] = cheque;
              }
            }
          }
        }
        command = LoanCommand(
          widget.action,
          body,
          before: create
              ? null
              : {
                  'loan': _page.loan!.json,
                  'installments': _page.schedule.map((s) => s.json).toList(),
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
        Alert.success(
          create
              ? 'پیش‌نویس و برنامه اقساط ثبت شد؛ جابه‌جایی اصل پول جدا ثبت می‌شود.'
              : (pay && (command.body['payment'] as Map?)?['method'] == 'CHEQUE'
                    ? 'چک ثبت شد؛ تا وصول، بازپرداخت قطعی محسوب نمی‌شود.'
                    : 'عملیات وام با موفقیت ثبت شد.'),
        );
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

  int remaining(LoanInstallment row, bool charge) => charge
      ? row.money('chargeAmount') -
            row.money('waivedChargeAmount') -
            row.money('paidChargeAmount') -
            row.money('pendingChargeAmount')
      : row.money('principalAmount') -
            row.money('paidPrincipalAmount') -
            row.money('pendingPrincipalAmount');

  int recognized(LoanInstallment row) {
    final accrued =
        DateTime.parse(row.json['dueAt'] as String)
            .isAfter(DateTime.now().toUtc())
        ? row.money('accruedChargeAmount')
        : row.money('chargeAmount') - row.money('waivedChargeAmount');
    final value =
        accrued -
        row.money('paidChargeAmount') -
        row.money('pendingChargeAmount');
    return value < 0 ? 0 : value;
  }

  Widget repaymentSummary() {
    try {
      var p = 0, c = 0, future = 0;
      for (final row in _page.schedule) {
        final inputs = _page.repayment[row.id]!;
        final selected = money(inputs.charge);
        p += money(inputs.principal);
        c += selected;
        final extra = selected - recognized(row);
        if (extra > 0) future += extra;
      }
      return Text(
        'جمع اصل: ${financialMoney(p)} | جمع هزینه: ${financialMoney(c)}\nجمع انتخابی: ${financialMoney(p + c)}\nاز هزینه انتخابی، هزینه آینده: ${financialMoney(future)}\nمبالغ بر پایه اطلاعات فعلی‌اند؛ نتیجه نهایی را سرور تأیید می‌کند.',
      );
    } on FormatException {
      return const Text('مبالغ اصل و هزینه را کامل کنید.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_LoanFormController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final funds = _page.targets
            .map((t) => ItemValue(text: t.name, data: t.id))
            .toList();
        final partnerItems = [
          const ItemValue(text: 'بدون ارتباط با شریک', data: null),
          ..._page.partners.map((p) => ItemValue(text: p.name, data: p.id)),
        ];
        return PopScope(
          canPop: !_page.saving,
          child: Main(
            initState: () async => '',
            header: Header.page(context, text: title),
            child: (_) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (busy) const Loader(),
                if (_page.error != null) Text(_page.error!),
                if (!_page.loading && _page.error == null) ...[
                  if (_page.loan != null) ...[
                    Text(_page.loan!.json['name'] as String),
                    Text(loanDirections[_page.loan!.json['direction']]!),
                    Text(
                      'اصل قرارداد: ${financialMoney(_page.loan!.money('principalAmount'))}',
                    ),
                    MyDivider(),
                  ],
                  if (fx.pending != null) ...[
                    const Text(
                      'ثبت قبلی با همان مشخصات پیگیری می‌شود؛ وجه را دوباره جابه‌جا نکنید.',
                    ),
                    if (create) Text('عنوان: ${fx.pending!.body['name']}'),
                    if (pay) ...[
                      Text(
                        'مبلغ بازپرداخت: ${financialMoney(RemoteJson(fx.pending!.body['payment']).number('amount'))}',
                      ),
                      if (fx.pending!.body['allocations'] != null) ...[
                        for (final part in RemoteJson(
                          fx.pending!.body,
                        ).items('allocations', RemoteJson.new))
                          Text(
                            'قسط ${_page.schedule.firstWhere((r) => r.id == part.text('loanInstallmentId')).json['number']}: اصل ${financialMoney(part.number('principalAmount'))} | هزینه ${financialMoney(part.number('chargeAmount'))}',
                          ),
                        Text(
                          fx.pending!.body['recognizeFutureCharges'] == true
                              ? 'شناسایی هزینه آینده در ثبت قبلی تأیید شده است.'
                              : 'هزینه آینده در ثبت قبلی تأیید نشده است.',
                        ),
                      ],
                    ],
                  ] else if (create) ...[
                    MyTab(
                      tab: loanDirections.values.toList(),
                      value: _page.direction,
                      callback: (v) {
                        if (!busy) {
                          _page.direction.value = v;
                          _page.update();
                        }
                      },
                    ),
                    Input(
                      controller: _page.name,
                      name: 'عنوان وام',
                      require: true,
                      maxLength: 200,
                      readOnly: busy,
                    ),
                    Input(
                      controller: _page.party,
                      name: 'طرف قرارداد',
                      require: true,
                      maxLength: 200,
                      readOnly: busy,
                    ),
                    Input(
                      controller: _page.phone,
                      name: 'تلفن طرف قرارداد (اختیاری)',
                      maxLength: 100,
                      readOnly: busy,
                    ),
                    Input(
                      controller: _page.reference,
                      name: 'مرجع قرارداد (اختیاری)',
                      maxLength: 100,
                      readOnly: busy,
                    ),
                    if (_page.partners.isNotEmpty)
                      Dropdown(
                        name: 'شریک مرتبط (اختیاری)',
                        itemValue: true,
                        disable: busy,
                        items_Value: partnerItems,
                        defaultValue: partnerItems
                            .where((p) => p.data == _page.partnerId)
                            .firstOrNull,
                        onChange: (v) =>
                            _page.partnerId = (v as ItemValue).data as String?,
                      ),
                    PriceInput(
                      controller: _page.principal,
                      name: 'اصل وام',
                      require: true,
                      readOnly: busy,
                    ),
                    PriceInput(
                      controller: _page.charge,
                      name: 'کل هزینه/درآمد مالی قراردادی',
                      require: true,
                      readOnly: busy,
                    ),
                    const Text(
                      'مبالغ و سررسیدهای توافق‌شده را وارد کنید؛ سود یا اقساط خودکار محاسبه نمی‌شوند.',
                    ),
                    for (final entry in _page.rows.asMap().entries) ...[
                      MyDivider(text: 'قسط ${entry.key + 1}'),
                      DateInput(
                        controller: entry.value.date,
                        name: 'سررسید قسط ${entry.key + 1}',
                        require: true,
                        enabled: !busy,
                        onChanged: (_) {},
                      ),
                      PriceInput(
                        controller: entry.value.principal,
                        name: 'اصل قسط ${entry.key + 1}',
                        require: true,
                        readOnly: busy,
                      ),
                      PriceInput(
                        controller: entry.value.charge,
                        name: 'هزینه/درآمد قسط ${entry.key + 1}',
                        require: true,
                        readOnly: busy,
                      ),
                      if (_page.rows.length > 1)
                        MiniBTN(
                          name: 'حذف قسط ${entry.key + 1}',
                          icon: IconsaxPlusLinear.trash,
                          noFlex: true,
                          onTap: busy
                              ? null
                              : () {
                                  {
                                    _page.rows.remove(entry.value);
                                    _page.update();
                                  }
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => entry.value.dispose(),
                                  );
                                },
                        ),
                    ],
                    if (_page.rows.length < 120)
                      MiniBTN(
                        name: 'افزودن قسط',
                        icon: IconsaxPlusLinear.add,
                        noFlex: true,
                        onTap: busy
                            ? null
                            : () {
                                _page.rows.add(_InstallmentInputs());
                                _page.update();
                              },
                      ),
                    Input(
                      controller: _page.note,
                      name: 'یادداشت (اختیاری)',
                      maxLength: 1000,
                      readOnly: busy,
                    ),
                  ] else ...[
                    if (fund || pay) ...[
                      Text(
                        fund
                            ? (_page.loan!.json['direction'] == 'RECEIVED'
                                  ? 'دریافت اصل وام در صندوق/حساب'
                                  : 'پرداخت اصل وام از صندوق/حساب')
                            : (_page.loan!.json['direction'] == 'RECEIVED'
                                  ? 'پرداخت بازپرداخت از صندوق/حساب'
                                  : 'دریافت بازپرداخت در صندوق/حساب'),
                      ),
                      if (pay) ...[
                        PriceInput(
                          controller: _page.amount,
                          name: 'مبلغ بازپرداخت',
                          currency: 'تومان',
                          require: true,
                          readOnly: busy,
                        ),
                        MyTab(
                          key: const ValueKey('loan-allocation-mode'),
                          tab: ['خودکار', 'انتخاب اقساط'],
                          value: _page.allocationMode,
                          callback: (v) {
                            if (!busy) {
                              _page.allocationMode.value = v;
                              _page.update();
                            }
                          },
                        ),
                        if (_page.allocationMode.value == 'خودکار')
                          const Text(
                            'سرور مبلغ را به هزینه شناسایی‌شده و اصل اقساط تخصیص می‌دهد؛ هزینه آینده خودکار پرداخت نمی‌شود.',
                          )
                        else ...[
                          const Text(
                            'برای هر قسط سهم اصل و هزینه را وارد کنید؛ صفر یعنی بدون تخصیص. مبالغ در انتظار چک از مانده آزاد کسر شده‌اند.',
                          ),
                          for (final row in _page.schedule) ...[
                            MyDivider(text: 'قسط ${row.json['number']}'),
                            Text(
                              'سررسید: ${DateConvertor.grigoriToJalali(row.json['dueAt'] as String)}',
                            ),
                            Text(
                              'مانده آزاد اصل: ${financialMoney(remaining(row, false))} | هزینه: ${financialMoney(remaining(row, true))}',
                            ),
                            PriceInput(
                              controller: _page.repayment[row.id]!.principal,
                              name: 'اصل قسط ${row.json['number']}',
                              currency: 'تومان',
                              readOnly: busy,
                              onChanged: (_) {
                                _page.update();
                              },
                            ),
                            PriceInput(
                              controller: _page.repayment[row.id]!.charge,
                              name: 'هزینه قسط ${row.json['number']}',
                              currency: 'تومان',
                              readOnly: busy,
                              onChanged: (_) {
                                _page.update();
                              },
                            ),
                          ],
                          MyDivider(text: 'خلاصه تخصیص'),
                          repaymentSummary(),
                          const Text(
                            'شناسایی و پرداخت هزینه قراردادی آینده را تأیید می‌کنم؛ این گزینه به معنی بخشودگی هزینه نیست.',
                          ),
                          MyTab(
                            tab: ['خیر', 'بله'],
                            key: const ValueKey('loan-future-charges'),
                            value: _page.futureCharges,
                            callback: (v) {
                              if (!busy) {
                                _page.futureCharges.value = v;
                                _page.update();
                              }
                            },
                          ),
                        ],
                      ],
                      DateInput(
                        controller: _page.date,
                        name: 'تاریخ جابه‌جایی وجه',
                        timePicker: true,
                        require: true,
                        enabled: !busy,
                        onChanged: (_) {},
                      ),
                      MyTab(
                        tab: [
                          'نقدی',
                          if (fx.access.canUseBank) ...[
                            'واریز بانکی',
                            if (pay) 'چک',
                          ],
                        ],
                        value: _page.method,
                        callback: (v) => loadTargets(v as String),
                      ),
                      Dropdown(
                        name: 'صندوق یا حساب',
                        itemValue: true,
                        disable: busy,
                        items_Value: funds,
                        defaultValue: funds
                            .where((f) => f.data == _page.fundId)
                            .firstOrNull,
                        onChange: (v) =>
                            _page.fundId = (v as ItemValue).data as String,
                      ),
                      MiniBTN(
                        name: 'دریافت مجدد صندوق‌ها',
                        icon: IconsaxPlusLinear.refresh,
                        noFlex: true,
                        onTap: busy
                            ? null
                            : () => loadTargets(_page.method.value),
                      ),
                      if (pay && methodCode == 'CHEQUE') ...[
                        MyDivider(text: 'اطلاعات چک'),
                        BankInput(
                          controller: _page.bank,
                          name: 'بانک چک',
                          require: true,
                          enabled: !busy,
                          onChanged: (_) {},
                        ),
                        Input(
                          controller: _page.chequeNumber,
                          name: 'شماره چک',
                          require: true,
                          maxLength: 64,
                          readOnly: busy,
                        ),
                        Input(
                          controller: _page.sayad,
                          name: 'شناسه صیاد (اختیاری)',
                          maxLength: 16,
                          readOnly: busy,
                        ),
                        Input(
                          controller: _page.drawer,
                          name: 'صادرکننده (اختیاری)',
                          maxLength: 200,
                          readOnly: busy,
                        ),
                        DateInput(
                          controller: _page.chequeDue,
                          name: 'سررسید چک',
                          require: true,
                          enabled: !busy,
                          onChanged: (_) {},
                        ),
                        const Text(
                          'مبلغ چک تا تعیین نتیجه، در اقساط رزرو می‌شود و پرداخت قطعی نیست.',
                        ),
                      ],
                      Input(
                        controller: _page.reference,
                        name: 'شماره پیگیری (اختیاری)',
                        maxLength: 200,
                        readOnly: busy,
                      ),
                    ],
                    if (!pay)
                      Input(
                        controller: _page.reason,
                        name: 'دلیل عملیات',
                        require: true,
                        maxLength: 500,
                        readOnly: busy,
                      ),
                    if (pay)
                      Input(
                        controller: _page.note,
                        name: 'یادداشت (اختیاری)',
                        maxLength: 1000,
                        readOnly: busy,
                      ),
                  ],
                  BTN(
                    key: const ValueKey('loan-save'),
                    name: fx.pending == null ? 'ثبت نهایی' : 'پیگیری ثبت قبلی',
                    disabled: busy,
                    onTap: save,
                  ),
                ],
                BTN(name: 'دریافت مجدد اطلاعات', disabled: busy, onTap: load),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget buildLoanFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return LoanForm(
    fx: args.required<LoansFX>('fx'),
    action: args.optional<String>('action') ?? 'create',
    loanId: args.optional<String>('loanId'),
  );
}
