import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/source/remote/models/invoice_payment.dart';
import 'package:mik_data/source/remote/models/remote_cheque.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/remote_cheques.dart';
import 'package:mik_data/utils/fx/customers.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/number.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

const chequeStatuses = {
  'PENDING': 'در انتظار',
  'CONFIRMED': 'وصول‌شده',
  'BOUNCED': 'برگشتی',
  'RETURNED': 'عودت‌شده',
};
typedef ChequeParty = ({String id, String type, String name});

class RemoteChequeScreen extends StatefulWidget {
  final String appId;
  final RemoteInvoiceSummary? invoice;
  const RemoteChequeScreen({required this.appId, this.invoice, super.key});
  @override
  State<RemoteChequeScreen> createState() => _RemoteChequeScreenState();
}

class _RemoteChequeScreenController extends GetxController {
  RemoteChequesFX? fx;
  List<RemoteCheque> rows = [];
  int direction = 0, filter = 0;
  bool loading = true, saving = false;
  String? error;
}

class _RemoteChequeScreenState extends State<RemoteChequeScreen> {
  late final _page = _RemoteChequeScreenController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    {
      _page.loading = true;
      _page.error = null;
      _page.rows = [];
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= RemoteChequesFX(active, invoice: widget.invoice);
      await _page.fx!.restore();
      await _page.fx!.authorize();
      final result = await _page.fx!.all();
      if (mounted) {
        _page.rows = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted) {
        _page.error = RemoteChequesFX.message(failure);
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

  Future<bool> send(ChequeCommand command) async {
    if (_page.saving || _page.fx == null) return false;
    {
      _page.saving = true;
      _page.update();
    }
    try {
      await _page.fx!.send(command);
      if (!mounted) return false;
      Alert.success(
        command.action == 'CREATE'
            ? 'چک با موفقیت ثبت شد؛ تا تعیین نتیجه در انتظار است.'
            : 'نتیجهٔ چک با موفقیت ثبت شد.',
      );
      return true;
    } catch (failure) {
      if (mounted) {
        _page.error = RemoteChequesFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
      return false;
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  Future<void> form({RemoteCheque? row}) async {
    if (_page.loading ||
        _page.saving ||
        _page.fx == null ||
        _page.fx!.pending != null)
      return;
    await Get.toNamed(
      nav_routes.RoutesName.CHEQUE_FORM,
      arguments: {
        'fx': _page.fx!,
        'row': row,
        'invoice': widget.invoice,
        'send': send,
      },
      preventDuplicates: false,
    );
    if (mounted) await load();
  }

  List<RemoteCheque> get visible {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return _page.rows.where((r) {
      final date = r.dueAt.toLocal();
      final due = DateTime(date.year, date.month, date.day);
      return (_page.direction == 0 ||
              r.direction == (_page.direction == 1 ? 'IN' : 'OUT')) &&
          switch (_page.filter) {
            1 => r.status == 'PENDING' && !due.isAfter(today),
            2 => r.status == 'CONFIRMED',
            3 => r.status == 'PENDING',
            4 => r.status == 'BOUNCED',
            5 => r.status == 'RETURNED',
            _ => true,
          };
    }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_RemoteChequeScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(
        context,
        text: widget.invoice == null
            ? 'چک‌ها'
            : 'چک‌های ${widget.invoice!.partyName}',
      ),
      floatingActionButton:
          _page.fx != null &&
              !_page.loading &&
              !_page.saving &&
              _page.fx!.pending == null &&
              (widget.invoice != null
                  ? _page.fx!.canCreate(widget.invoice!.partyType)
                  : _page.fx!.canCreate('CUSTOMER') ||
                        _page.fx!.canCreate('SUPPLIER'))
          ? MyFAB(icon: IconsaxPlusLinear.add, text: 'چک جدید', onTap: form)
          : const SizedBox.shrink(),
      child: (_) => Column(
        children: [
          MyTabBar(
            tabs: const ['همه', 'دریافتی', 'پرداختی'],
            currentIndex: _page.direction,
            divider: false,
            index: (i) {
              _page.direction = i as int;
              _page.update();
            },
          ),
          MyTabBar(
            tabs: const [
              'همه',
              'سررسید',
              'وصول‌شده',
              'در انتظار',
              'برگشتی',
              'عودت‌شده',
            ],
            currentIndex: _page.filter,
            divider: false,
            index: (i) {
              _page.filter = i as int;
              _page.update();
            },
          ),
          if (_page.loading || _page.saving) const LinearProgressIndicator(),
          if (_page.error != null)
            Text(_page.error!, textAlign: TextAlign.center),
          MiniBTN(
            name: 'دریافت مجدد چک‌ها',
            icon: IconsaxPlusLinear.refresh,
            noFlex: true,
            onTap: _page.loading || _page.saving ? null : load,
          ),
          if (_page.fx?.pending != null)
            BTN(
              name: 'پیگیری درخواست قبلی چک',
              disabled: _page.saving || _page.loading,
              onTap: () async {
                if (await send(_page.fx!.pending!)) await load();
              },
            ),
          if (widget.invoice != null)
            const Text(
              'فهرست چک‌های طرف حساب است؛ ثبت یا وصول چک الزاماً به معنی تسویهٔ همین فاکتور نیست.',
            ),
          Expanded(
            child: !_page.loading && _page.error == null && visible.isEmpty
                ? const Center(child: Text('چکی برای این فیلتر وجود ندارد.'))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 90),
                    children: [
                      for (final row in visible)
                        Column(
                          children: [
                            InkWell(
                              onTap: () => form(row: row),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(IconsaxPlusLinear.document),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${row.bankName} — ${row.number}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${row.direction == 'IN' ? 'دریافتی' : 'پرداختی'}: ${Number.addCommas(row.amount)} تومان',
                                          ),
                                          Text(
                                            'سررسید: ${DateConvertor.grigoriToJalali(row.dueAt.toLocal())}',
                                          ),
                                          if (row.drawerName != null)
                                            Text(row.drawerName!),
                                        ],
                                      ),
                                    ),
                                    Text(chequeStatuses[row.status]!),
                                  ],
                                ),
                              ),
                            ),
                            EndLine(),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ChequeForm extends StatefulWidget {
  final RemoteChequesFX fx;
  final RemoteCheque? row;
  final RemoteInvoiceSummary? invoice;
  final Future<bool> Function(ChequeCommand) send;
  const _ChequeForm({
    required this.fx,
    required this.send,
    this.row,
    this.invoice,
  });
  @override
  State<_ChequeForm> createState() => _ChequeFormState();
}

class _ChequeFormController extends GetxController {
  final amount = TextEditingController(),
      bank = TextEditingController(),
      number = TextEditingController(),
      sayad = TextEditingController(),
      drawer = TextEditingController(),
      due = TextEditingController(),
      reason = TextEditingController();
  final result = 'وصول‌شده'.obs, confirmed = 'خیر'.obs, partyType = 'مشتری'.obs;
  RemoteCheque? current;
  InvoicePaymentDetail? linkedPayment;
  ChequeParty? party;
  List<({String id, String name})> banks = [];
  String? fundId, error;
  bool loading = true, saving = false;
}

class _ChequeFormState extends State<_ChequeForm> {
  late final _page = _ChequeFormController();

  bool get create => widget.row == null;
  bool get editable =>
      !_page.loading &&
      !_page.saving &&
      _page.error == null &&
      (create
          ? _page.party != null && widget.fx.canCreate(_page.party!.type)
          : _page.current?.status == 'PENDING' &&
                _page.current?.branchId == widget.fx.branchId &&
                widget.fx.canClear &&
                _page.linkedPayment != null);
  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      _page.party = (
        id: widget.invoice!.partyId,
        type: widget.invoice!.partyType,
        name: widget.invoice!.partyName,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _page.amount,
      _page.bank,
      _page.number,
      _page.sayad,
      _page.drawer,
      _page.due,
      _page.reason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    {
      _page.loading = true;
      _page.error = null;
      _page.update();
    }
    _page.confirmed.value = 'خیر';
    try {
      await widget.fx.authorize();
      if (create) {
        _page.banks = await widget.fx.banks();
      } else {
        _page.current = await widget.fx.get(widget.row!.id);
        if (_page.current!.branchId == widget.fx.branchId &&
            _page.current!.status == 'PENDING' &&
            widget.fx.canClear) {
          _page.linkedPayment = await widget.fx.payment(_page.current!);
          if (_page.linkedPayment!.routing == null) {
            _page.banks = await widget.fx.banks();
          } else {
            _page.fundId = _page.linkedPayment!.routing!['fundId'] as String;
          }
        }
      }
    } catch (failure) {
      if (mounted) {
        _page.error = RemoteChequesFX.message(failure);
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

  Future<void> pickParty(String type) async {
    {
      _page.loading = true;
      _page.update();
    }
    try {
      final rows = <ChequeParty>[];
      if (type == 'CUSTOMER') {
        final fx = CustomersFX(context: widget.fx.context);
        await fx.authorize();
        String? after;
        final cursors = <String>{};
        do {
          final page = await fx.page(after: after);
          rows.addAll(
            page.items
                .where((r) => !r.isDefault)
                .map((r) => (id: r.id, type: type, name: r.name)),
          );
          after = page.next;
          if (after != null && !cursors.add(after)) {
            throw const FormatException('Repeated customer cursor');
          }
        } while (after != null);
      } else {
        final fx = SuppliersFX.forContext(widget.fx.context);
        await fx.authorize();
        rows.addAll(
          (await fx.all()).map((r) => (id: r.id, type: type, name: r.name)),
        );
      }
      widget.fx.check();
      if (!mounted) return;
      final selected = await MyBottomSheet.view(
        context,
        title: type == 'CUSTOMER' ? 'انتخاب مشتری' : 'انتخاب تأمین‌کننده',
        child: (controller) => ListView(
          shrinkWrap: true,
          controller: controller,
          children: [
            if (rows.isEmpty) const Text('طرف حساب فعالی یافت نشد.'),
            for (final row in rows)
              MiniBTN(
                name: row.name,
                icon: IconsaxPlusLinear.user,
                noFlex: true,
                onTap: () => Get.back(result: row),
              ),
          ],
        ),
      );
      if (mounted && selected is ChequeParty) {
        _page.party = selected;
        _page.update();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(RemoteChequesFX.message(failure), context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  String text(TextEditingController value, int max, {bool required = false}) {
    final v = value.text.trim();
    if ((required && v.isEmpty) ||
        v.length > max ||
        RegExp(r'[\u0000-\u0008]').hasMatch(v)) {
      throw const FormatException('Invalid cheque text');
    }
    return v;
  }

  Future<void> save() async {
    if (!editable) return;
    try {
      if (_page.confirmed.value != 'بله') {
        throw const FormatException('Actual result not confirmed');
      }
      late ChequeCommand command;
      if (create) {
        final value = int.tryParse(
          _page.amount.text.toEnglishDigit().replaceAll(',', '').trim(),
        );
        final money = RemoteInvoiceSummary.money(value);
        if (money == 0 || _page.fundId == null) {
          throw const FormatException('Amount and bank required');
        }
        final cheque = <String, dynamic>{
          'bankName': text(_page.bank, 100, required: true),
          'number': text(_page.number, 64, required: true),
          'dueAt': DateTime.parse(
            DateConvertor.jalaliToGrigori(_page.due.text.toEnglishDigit()),
          ).toUtc().toIso8601String(),
          if (_page.sayad.text.trim().isNotEmpty)
            'sayadId': text(_page.sayad, 16).toEnglishDigit(),
          if (_page.drawer.text.trim().isNotEmpty)
            'drawerName': text(_page.drawer, 200),
        };
        if (cheque['sayadId'] != null &&
            !RegExp(r'^\d{16}$').hasMatch(cheque['sayadId'] as String)) {
          throw const FormatException('Invalid Sayad id');
        }
        command = ChequeCommand('CREATE', {
          'partyType': _page.party!.type,
          'partyId': _page.party!.id,
          'payment': {
            'method': 'CHEQUE',
            'direction': _page.party!.type == 'CUSTOMER' ? 'IN' : 'OUT',
            'amount': money,
            'confirmed': true,
            'routing': {'fundId': _page.fundId},
            'cheque': cheque,
          },
        });
      } else {
        if (_page.fundId == null) throw const FormatException('Bank required');
        command = ChequeCommand(
          'STATUS',
          {
            'chequeId': _page.current!.id,
            'expectedRevision': _page.current!.revision,
            'status': chequeStatuses.entries
                .firstWhere((e) => e.value == _page.result.value)
                .key,
            'confirmed': true,
            'reason': text(_page.reason, 500, required: true),
            if (_page.linkedPayment!.routing == null)
              'routing': {'fundId': _page.fundId},
          },
          before: {
            'cheque': _page.current!.json,
            'payment': _page.linkedPayment!.json,
          },
        );
      }
      {
        _page.saving = true;
        _page.update();
      }
      final success = await widget.send(command);
      if (!mounted) return;
      if (success || widget.fx.pending != null) {
        Get.back();
      } else {
        {
          _page.saving = false;
          _page.update();
        }
        await load();
      }
    } catch (failure) {
      if (mounted) {
        {
          _page.saving = false;
          _page.update();
        }
        Alert.error(
          'مشخصات، سررسید، مبلغ، حساب بانکی و تایید واقعی چک را بررسی کنید.',
          context: context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_ChequeFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: create ? 'ثبت چک' : 'جزئیات و نتیجهٔ چک',
        ),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null)
              Text(_page.error!, textAlign: TextAlign.center),
            MiniBTN(
              name: 'دریافت مجدد جزئیات',
              icon: IconsaxPlusLinear.refresh,
              noFlex: true,
              onTap: _page.loading || _page.saving ? null : load,
            ),
            if (create) ...[
              if (widget.invoice == null) ...[
                IgnorePointer(
                  ignoring: _page.loading || _page.saving,
                  child: MyTab(
                    tab: const ['مشتری', 'تأمین‌کننده'],
                    value: _page.partyType,
                    callback: (String value) {
                      _page.partyType.value = value;
                      {
                        _page.party = null;
                        _page.update();
                      }
                    },
                  ),
                ),
                MiniBTN(
                  name: _page.partyType.value == 'مشتری'
                      ? 'انتخاب مشتری'
                      : 'انتخاب تأمین‌کننده',
                  icon: IconsaxPlusLinear.user,
                  noFlex: true,
                  onTap: _page.loading || _page.saving
                      ? null
                      : () => pickParty(
                          _page.partyType.value == 'مشتری'
                              ? 'CUSTOMER'
                              : 'SUPPLIER',
                        ),
                ),
              ],
              if (_page.party != null) Text('طرف حساب: ${_page.party!.name}'),
              const Text(
                'چک تا زمان تعیین نتیجه در انتظار است و وجه قطعی یا تسویهٔ قطعی محسوب نمی‌شود.',
              ),
              Input(
                key: const ValueKey('cheque-amount'),
                controller: _page.amount,
                name: 'مبلغ (تومان)',
                require: true,
                keyboardType: TextInputType.number,
                readOnly: _page.loading || _page.saving,
              ),
              Input(
                key: const ValueKey('cheque-bank'),
                controller: _page.bank,
                name: 'نام بانک روی چک',
                require: true,
                maxLength: 100,
                readOnly: _page.loading || _page.saving,
              ),
              Input(
                key: const ValueKey('cheque-number'),
                controller: _page.number,
                name: 'شماره چک',
                require: true,
                maxLength: 64,
                readOnly: _page.loading || _page.saving,
              ),
              Input(
                key: const ValueKey('cheque-sayad'),
                controller: _page.sayad,
                name: 'شناسه صیادی (۱۶ رقم)',
                maxLength: 16,
                keyboardType: TextInputType.number,
                readOnly: _page.loading || _page.saving,
              ),
              Input(
                controller: _page.drawer,
                name: 'نام صادرکننده',
                maxLength: 200,
                readOnly: _page.loading || _page.saving,
              ),
              IgnorePointer(
                ignoring: _page.loading || _page.saving,
                child: DateInput(
                  key: const ValueKey('cheque-due'),
                  controller: _page.due,
                  name: 'تاریخ سررسید',
                  require: true,
                  onChanged: (_) {
                    _page.update();
                  },
                ),
              ),
            ],
            if (_page.current != null) ...[
              Text('${_page.current!.bankName} — ${_page.current!.number}'),
              Text('مبلغ: ${Number.addCommas(_page.current!.amount)} تومان'),
              Text('وضعیت: ${chequeStatuses[_page.current!.status]}'),
              Text(
                'سررسید: ${DateConvertor.grigoriToJalali(_page.current!.dueAt.toLocal())}',
              ),
              if (_page.current!.sayadId != null)
                SelectableText('صیادی: ${_page.current!.sayadId}'),
              if (_page.current!.drawerName != null)
                Text('صادرکننده: ${_page.current!.drawerName}'),
              SelectableText('طرف حساب: ${_page.current!.partyId}'),
              if (_page.current!.branchId != widget.fx.branchId)
                const Text(
                  'برای تعیین نتیجه، شعبهٔ ثبت‌کنندهٔ چک را انتخاب کنید.',
                ),
              if (_page.current!.status != 'PENDING')
                const Text(
                  'نتیجهٔ این چک نهایی شده است؛ تغییر دوبارهٔ وضعیت مجاز نیست.',
                ),
              if (editable) ...[
                IgnorePointer(
                  ignoring: _page.saving,
                  child: MyTab(
                    tab: const ['وصول‌شده', 'برگشتی', 'عودت‌شده'],
                    value: _page.result,
                    callback: (String v) => _page.result.value = v,
                  ),
                ),
                Input(
                  key: const ValueKey('cheque-reason'),
                  controller: _page.reason,
                  name: 'دلیل و توضیح نتیجه',
                  require: true,
                  maxLength: 500,
                  readOnly: _page.saving,
                ),
              ],
            ],
            if (create || editable) ...[
              MyDivider(text: 'حساب بانکی چک'),
              if (_page.linkedPayment?.routing != null)
                const Text(
                  'حساب بانکی هنگام ثبت تعیین شده و در این مرحله قابل تغییر نیست.',
                )
              else ...[
                if (_page.banks.isEmpty && !_page.loading)
                  const Text('حساب بانکی فعالی برای استفاده دریافت نشد.'),
                for (final row in _page.banks)
                  MiniBTN(
                    name: '${_page.fundId == row.id ? '✓ ' : ''}${row.name}',
                    icon: IconsaxPlusLinear.bank,
                    noFlex: true,
                    onTap: _page.loading || _page.saving
                        ? null
                        : () {
                            _page.fundId = row.id;
                            _page.update();
                          },
                  ),
              ],
              const Text(
                'آیا دریافت/تحویل واقعی چک یا نتیجهٔ انتخاب‌شده را تایید می‌کنید؟',
              ),
              IgnorePointer(
                ignoring: _page.loading || _page.saving,
                child: MyTab(
                  tab: const ['خیر', 'بله'],
                  value: _page.confirmed,
                  callback: (String v) => _page.confirmed.value = v,
                ),
              ),
              BTN(
                name: create ? 'ثبت چک' : 'ثبت نتیجهٔ چک',
                disabled: !editable,
                onTap: save,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildChequeFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _ChequeForm(
    fx: args.required<RemoteChequesFX>('fx'),
    send: args.required<Future<bool> Function(ChequeCommand)>('send'),
    row: args.optional<RemoteCheque>('row'),
    invoice: args.optional<RemoteInvoiceSummary>('invoice'),
  );
}

Widget buildRemoteChequeRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return RemoteChequeScreen(
    appId: args.required<String>('appId'),
    invoice: args.optional<RemoteInvoiceSummary>('invoice'),
  );
}
