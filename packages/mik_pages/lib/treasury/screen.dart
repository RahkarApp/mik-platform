import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_data/utils/fx/realtime.dart';
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
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/treasury.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/treasury.dart';
import 'package:mik_utils/public/price.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class TreasuryScreen extends StatefulWidget {
  final String appId, branchId;
  const TreasuryScreen({
    required this.appId,
    required this.branchId,
    super.key,
  });
  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenController extends GetxController {
  RealtimeWatch? _realtime;
  final tab = 'صندوق‌ها'.obs;
  TreasuryFX? fx;
  List<TreasuryFund> funds = [];
  List<TreasuryTerminal> terminals = [];
  bool loading = true, saving = false, conflict = false, opening = false;
  String? error;
  int generation = 0;
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  late final _page = _TreasuryScreenController();

  static const sections = {
    'صندوق‌ها': 'CASH',
    'تنخواه': 'PETTY_CASH',
    'حساب بانکی': 'BANK',
    'کارت‌خوان': 'terminal',
  };

  String get section => sections[_page.tab.value]!;
  bool get canRead =>
      _page.fx != null &&
      (section == 'BANK'
          ? _page.fx!.has('accounting.bank.read', business: true)
          : _page.fx!.has(
              section == 'terminal'
                  ? 'accounting.terminal.read'
                  : 'accounting.treasury.read',
            ));
  bool get canCreate =>
      canRead &&
      (section == 'terminal'
          ? _page.fx!.canManageTerminal && _page.fx!.canUseBank
          : _page.fx!.canManageFund(section));
  @override
  void initState() {
    super.initState();
    final realtimeContext = BusinessContext.forApp(widget.appId);
    if (realtimeContext != null) {
      _page._realtime = RealtimeWatch(
        RealtimeFX.forContext(realtimeContext),
        {
          'accounting.cash-fund',
          'accounting.bank-fund',
          'accounting.terminal',
          'accounting.fund-hold',
          'accounting.transfer',
          'accounting.card-settlement',
          'accounting.cash-shift',
          'accounting.cash-shift-entry',
        },
        () async {
          await load(background: true);
        },
        busy: () => _page.loading || _page.saving || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page.generation++;
              _page.loading = false;
              _page.funds = [];
              _page.terminals = [];
              _page.update();
            }
          }
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page.generation++;
    _page.generation++;
    super.dispose();
  }

  Future<Object> load({bool background = false}) async {
    if (_page.saving) return '';
    final request = ++_page.generation;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      _page.conflict = false;
      if (!background) _page.funds = [];
      if (!background) _page.terminals = [];
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= TreasuryFX.forContext(active, widget.branchId);
      await _page.fx!.authorize();
      await _page.fx!.restore();
      if (!mounted || request != _page.generation) return '';
      if (!canRead) throw const AuthError(403, 'FORBIDDEN');
      final loadedFunds = section == 'terminal'
          ? <TreasuryFund>[]
          : await _page.fx!.funds(section);
      final loadedTerminals = section == 'terminal'
          ? await _page.fx!.terminals()
          : <TreasuryTerminal>[];
      if (mounted && request == _page.generation) {
        {
          _page.funds = loadedFunds;
          _page.terminals = loadedTerminals;
          _page.update();
        }
      }
    } catch (failure) {
      if (mounted && request == _page.generation) {
        _page.error = TreasuryFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted && request == _page.generation) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<bool> send(TreasuryCommand command) async {
    if (_page.saving || _page.fx == null) return false;
    {
      _page.saving = true;
      _page.error = null;
      _page.update();
    }
    try {
      await _page.fx!.send(command);
      if (!mounted) return false;
      Alert.success('اطلاعات خزانه با موفقیت ثبت شد.');
      return true;
    } catch (failure) {
      if (mounted) {
        {
          _page.error = TreasuryFX.message(failure);
          _page.conflict =
              failure is AuthError && failure.code == 'REVISION_CONFLICT';
          _page.update();
        }
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

  Future<void> resume() async {
    final command = _page.fx?.pending;
    if (command != null && await send(command)) await load();
  }

  Future<void> form({TreasuryFund? fund, TreasuryTerminal? terminal}) async {
    if (_page.loading ||
        _page.saving ||
        _page.fx == null ||
        _page.fx!.pending != null)
      return;
    List<TreasuryFund> banks = [];
    if (section == 'terminal' &&
        _page.fx!.canUseBank &&
        _page.fx!.has('accounting.bank.read', business: true)) {
      try {
        banks = (await _page.fx!.funds('BANK'))
            .where((r) => r.status == 'ACTIVE')
            .toList();
      } catch (failure) {
        if (mounted) Alert.error(TreasuryFX.message(failure), context: context);
        return;
      }
    }
    if (!mounted) return;
    _page.opening = true;
    try {
      await Get.toNamed(
        nav_routes.RoutesName.TREASURY_FORM,
        arguments: {
          'kind': section,
          'fund': fund,
          'terminal': terminal,
          'banks': banks,
          'canChooseBank': _page.fx!.canUseBank,
          'save': send,
          'needsReload': () => _page.fx!.pending != null || _page.conflict,
        },
        preventDuplicates: false,
      );
    } finally {
      _page.opening = false;
    }
    if (mounted) await load();
  }

  Future<void> details({TreasuryFund? fund, TreasuryTerminal? terminal}) async {
    final editable = fund != null
        ? _page.fx!.canManageFund(fund.kind)
        : _page.fx!.canManageTerminal;
    final edit = await MyBottomSheet.view(
      context,
      title: fund?.name ?? terminal!.name,
      child: (_) => Column(
        children: [
          SelectableText('شناسه: ${fund?.id ?? terminal!.id}'),
          MyDivider(),
          Text(
            'وضعیت: ${(fund?.status ?? terminal!.status) == 'ACTIVE' ? 'فعال' : 'آرشیو'}',
          ),
          if (fund != null) ...[
            Text('مانده: ${Price.showWithCurrency(fund.balance)}'),
            Text(
              'قابل استفاده: ${Price.showWithCurrency(fund.availableAmount)}',
            ),
            if (fund.bankName != null) Text('بانک: ${fund.bankName}'),
            if (fund.accountNumber != null)
              SelectableText('شماره حساب: ${fund.accountNumber}'),
            if (fund.iban != null) SelectableText('شبا: ${fund.iban}'),
          ],
          if (terminal != null) ...[
            SelectableText('شناسه حساب بانکی: ${terminal.fundId}'),
            if (terminal.terminalNumber != null)
              Text('شماره پایانه: ${terminal.terminalNumber}'),
            if (terminal.merchantNumber != null)
              Text('شماره پذیرنده: ${terminal.merchantNumber}'),
            if (terminal.providerName != null)
              Text('شرکت ارائه‌دهنده: ${terminal.providerName}'),
          ],
          MyDivider(),
          if (editable && _page.fx!.pending == null)
            MiniBTN(
              name: 'ویرایش',
              noFlex: true,
              icon: IconsaxPlusLinear.edit_2,
              onTap: () => Get.back(result: true),
            ),
          BTN(name: 'بستن', onTap: () => Get.back()),
        ],
      ),
    );
    if (mounted && edit == true) await form(fund: fund, terminal: terminal);
  }

  Widget item(
    String name,
    String subtitle,
    String status,
    VoidCallback onTap,
  ) => Column(
    children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.boxBackground,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(IconsaxPlusLinear.wallet),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(subtitle),
                  ],
                ),
              ),
              Text(status == 'ACTIVE' ? 'فعال' : 'آرشیو'),
            ],
          ),
        ),
      ),
      EndLine(),
    ],
  );
  @override
  Widget build(BuildContext context) => GetBuilder<_TreasuryScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(context, text: 'صندوق‌ها و حساب‌ها'),
      floatingActionButton:
          canCreate &&
              !_page.loading &&
              !_page.saving &&
              _page.fx?.pending == null
          ? MyFAB(
              icon: IconsaxPlusLinear.add,
              text:
                  'افزودن ${_page.tab.value == 'صندوق‌ها' ? 'صندوق' : _page.tab.value}',
              onTap: form,
            )
          : const SizedBox.shrink(),
      child: (_) => Column(
        children: [
          MyTab(
            tab: sections.keys.toList(),
            value: _page.tab,
            width: false,
            widthSize: (MediaQuery.sizeOf(context).width - 50) / 4,
            callback: (String value) {
              if (!_page.saving && !_page.loading) {
                _page.tab.value = value;
                load();
              }
            },
          ),
          if (_page.loading || _page.saving) const LinearProgressIndicator(),
          if (_page.error != null)
            Text(_page.error!, textAlign: TextAlign.center),
          MiniBTN(
            name: 'دریافت مجدد',
            noFlex: true,
            icon: IconsaxPlusLinear.refresh,
            onTap: _page.loading || _page.saving ? null : load,
          ),
          if (_page.fx?.pending != null) ...[
            const Text(
              'پاسخ درخواست قبلی مشخص نیست؛ همان درخواست را پیگیری کنید.',
            ),
            BTN(
              name: 'پیگیری ثبت خزانه',
              disabled: _page.loading || _page.saving,
              onTap: resume,
            ),
          ],
          if (section == 'BANK')
            const Text('حساب‌های بانکی متعلق به کل کسب‌وکار هستند.'),
          Expanded(
            child:
                !_page.loading &&
                    _page.error == null &&
                    _page.funds.isEmpty &&
                    _page.terminals.isEmpty
                ? const Center(child: Text('موردی تعریف نشده است.'))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 90),
                    children: [
                      for (final row in _page.funds)
                        item(
                          row.name,
                          'قابل استفاده: ${Price.showWithCurrency(row.availableAmount)}',
                          row.status,
                          () => details(fund: row),
                        ),
                      for (final row in _page.terminals)
                        item(
                          row.name,
                          row.providerName ?? 'کارت‌خوان',
                          row.status,
                          () => details(terminal: row),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _TreasuryForm extends StatefulWidget {
  final String kind;
  final TreasuryFund? fund;
  final TreasuryTerminal? terminal;
  final List<TreasuryFund> banks;
  final bool canChooseBank;
  final Future<bool> Function(TreasuryCommand) save;
  final bool Function() needsReload;
  const _TreasuryForm({
    required this.kind,
    this.fund,
    this.terminal,
    required this.banks,
    required this.canChooseBank,
    required this.save,
    required this.needsReload,
  });
  @override
  State<_TreasuryForm> createState() => _TreasuryFormState();
}

class _TreasuryFormController extends GetxController {
  _TreasuryFormController(this.widget);
  _TreasuryForm widget;
  late final Map<String, TextEditingController> fields = {
    'name': TextEditingController(
      text: widget.fund?.name ?? widget.terminal?.name ?? '',
    ),
    for (final key in [
      'bankName',
      'accountNumber',
      'iban',
      'terminalNumber',
      'merchantNumber',
      'providerName',
    ])
      key: TextEditingController(
        text:
            (widget.fund?.json[key] ?? widget.terminal?.json[key]) as String? ??
            '',
      ),
  };
  late final status =
      ((widget.fund?.status ?? widget.terminal?.status) == 'ARCHIVED'
              ? 'آرشیو'
              : 'فعال')
          .obs;
  late String? fundId = widget.terminal?.fundId;
  bool saving = false;
}

class _TreasuryFormState extends State<_TreasuryForm> {
  late final _page = _TreasuryFormController(widget);

  bool get update => widget.fund != null || widget.terminal != null;
  @override
  void dispose() {
    for (final input in _page.fields.values) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (_page.saving) return;
    final body = <String, dynamic>{};
    for (final key in [
      'name',
      if (widget.kind == 'BANK') ...['bankName', 'accountNumber', 'iban'],
      if (widget.kind == 'terminal') ...[
        'terminalNumber',
        'merchantNumber',
        'providerName',
      ],
    ]) {
      var value = _page.fields[key]!.text.trim();
      if (['accountNumber', 'iban'].contains(key)) {
        value = value.toEnglishDigit();
      }
      if (key == 'iban') value = value.toUpperCase();
      if (value.isEmpty && key != 'name') continue;
      if (value.isEmpty ||
          value.length > (key == 'name' ? 200 : 100) ||
          RegExp(r'[\u0000-\u0008]').hasMatch(value)) {
        Alert.error('نام و مشخصات واردشده معتبر نیست.', context: context);
        return;
      }
      body[key] = value;
    }
    if (body['accountNumber'] != null &&
        !RegExp(r'^\d{3,30}$').hasMatch(body['accountNumber'] as String)) {
      Alert.error('شماره حساب باید بین ۳ تا ۳۰ رقم باشد.', context: context);
      return;
    }
    if (body['iban'] != null) {
      final iban = body['iban'] as String;
      final valid = RegExp(r'^IR\d{24}$').hasMatch(iban);
      final numeric = valid
          ? (iban.substring(4) + iban.substring(0, 4)).replaceAllMapped(
              RegExp('[A-Z]'),
              (m) => '${m[0]!.codeUnitAt(0) - 55}',
            )
          : '';
      if (!valid || BigInt.parse(numeric) % BigInt.from(97) != BigInt.one) {
        Alert.error(
          'شماره شبا معتبر نیست؛ IR و ۲۴ رقم را وارد کنید.',
          context: context,
        );
        return;
      }
    }
    if (widget.kind == 'terminal') {
      if (!update || _page.fundId != widget.terminal!.fundId) {
        if (_page.fundId == null ||
            !widget.canChooseBank ||
            !widget.banks.any((r) => r.id == _page.fundId)) {
          Alert.error(
            'یک حساب بانکی فعال انتخاب کنید؛ مجوز مشاهده و استفاده از حساب بانکی لازم است.',
            context: context,
          );
          return;
        }
        body['fundId'] = _page.fundId;
      }
      if (update) body['terminalId'] = widget.terminal!.id;
    } else if (update) {
      body['fundId'] = widget.fund!.id;
    } else {
      body['kind'] = widget.kind;
    }
    if (update) {
      body['expectedRevision'] =
          widget.fund?.revision ?? widget.terminal!.revision;
      body['status'] = _page.status.value == 'فعال' ? 'ACTIVE' : 'ARCHIVED';
    }
    {
      _page.saving = true;
      _page.update();
    }
    final done = await widget.save(
      TreasuryCommand(widget.kind == 'terminal' ? 'terminals' : 'funds', body),
    );
    if (!mounted) return;
    // Ambiguous replies and revision conflicts are handled by the list retry/reload controls.
    if (done || widget.needsReload()) {
      Get.back();
    } else {
      {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_TreasuryFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: update ? 'ویرایش' : 'افزودن'),
        child: (_) => Column(
          children: [
            if (_page.saving) const LinearProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Input(
                      key: const ValueKey('treasury-name'),
                      controller: _page.fields['name']!,
                      name: 'نام',
                      require: true,
                      maxLength: 200,
                      readOnly: _page.saving,
                    ),
                    if (widget.kind == 'BANK') ...[
                      Input(
                        controller: _page.fields['bankName']!,
                        name: 'نام بانک',
                        maxLength: 100,
                        readOnly: _page.saving,
                      ),
                      Input(
                        controller: _page.fields['accountNumber']!,
                        name: 'شماره حساب',
                        maxLength: 30,
                        readOnly: _page.saving,
                        keyboardType: TextInputType.number,
                      ),
                      Input(
                        controller: _page.fields['iban']!,
                        name: 'شماره شبا',
                        maxLength: 26,
                        readOnly: _page.saving,
                      ),
                    ],
                    if (widget.kind == 'terminal') ...[
                      MyDivider(text: 'حساب بانکی متصل'),
                      if (widget.banks.isEmpty)
                        const Text(
                          'حساب بانکی فعالی برای انتخاب دریافت نشد؛ ابتدا حساب بانکی را تعریف و مجوزها را بررسی کنید.',
                        ),
                      if (widget.terminal != null &&
                          !widget.banks.any(
                            (r) => r.id == widget.terminal!.fundId,
                          ))
                        SelectableText('حساب فعلی: ${widget.terminal!.fundId}'),
                      for (final bank in widget.banks)
                        MiniBTN(
                          name:
                              '${_page.fundId == bank.id ? '✓ ' : ''}${bank.name}',
                          icon: IconsaxPlusLinear.bank,
                          noFlex: true,
                          onTap: _page.saving || !widget.canChooseBank
                              ? null
                              : () {
                                  _page.fundId = bank.id;
                                  _page.update();
                                },
                        ),
                      Input(
                        controller: _page.fields['terminalNumber']!,
                        name: 'شماره پایانه',
                        maxLength: 100,
                        readOnly: _page.saving,
                      ),
                      Input(
                        controller: _page.fields['merchantNumber']!,
                        name: 'شماره پذیرنده',
                        maxLength: 100,
                        readOnly: _page.saving,
                      ),
                      Input(
                        controller: _page.fields['providerName']!,
                        name: 'شرکت ارائه‌دهنده',
                        maxLength: 100,
                        readOnly: _page.saving,
                      ),
                    ],
                    if (update) ...[
                      MyDivider(text: 'وضعیت'),
                      IgnorePointer(
                        ignoring: _page.saving,
                        child: MyTab(
                          tab: const ['فعال', 'آرشیو'],
                          value: _page.status,
                          callback: (String v) => _page.status.value = v,
                        ),
                      ),
                      const Text(
                        'آرشیو فقط در صورت نبود مانده و تعهد یا اتصال فعال توسط سرور پذیرفته می‌شود.',
                      ),
                    ],
                    if (widget.kind == 'BANK' && update)
                      const Text(
                        'خالی‌گذاشتن مشخصات اختیاری، مقدار قبلی را حفظ می‌کند. شماره حساب استفاده‌شده قابل تغییر نیست.',
                      ),
                  ],
                ),
              ),
            ),
            BTN(name: 'ذخیره', disabled: _page.saving, onTap: save),
          ],
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant _TreasuryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

Widget buildTreasuryRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return TreasuryScreen(
    appId: args.required<String>('appId'),
    branchId: args.required<String>('branchId'),
  );
}

Widget buildTreasuryFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _TreasuryForm(
    kind: args.required<String>('kind'),
    fund: args.optional<TreasuryFund>('fund'),
    terminal: args.optional<TreasuryTerminal>('terminal'),
    banks: args.required<List<TreasuryFund>>('banks'),
    canChooseBank: args.required<bool>('canChooseBank'),
    save: args.required<Future<bool> Function(TreasuryCommand)>('save'),
    needsReload: args.required<bool Function()>('needsReload'),
  );
}
