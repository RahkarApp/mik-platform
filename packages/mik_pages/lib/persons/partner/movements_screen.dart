import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/partner_movement.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/partner_movements.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import '../../reports/financial_screen.dart' show financialMoney;

String partnerMovementMessage(Object failure) {
  if (failure is FormatException) {
    return 'اطلاعات گردش شریک معتبر نیست؛ اطلاعات را تازه یا درخواست قبلی را پیگیری کنید.';
  }
  if (failure is AuthError) {
    if (failure.code == 'FORBIDDEN') {
      return 'مجوز این عملیات شریک یا استفاده از صندوق و حساب انتخاب‌شده را ندارید.';
    }
    if (failure.code == 'REVISION_CONFLICT') {
      return 'اطلاعات شریک تغییر کرده است؛ اطلاعات را تازه کنید.';
    }
    if (failure.code == 'IDEMPOTENCY_CONFLICT') {
      return 'ابتدا درخواست قبلی شرکا را پیگیری کنید.';
    }
    if (failure.code == 'INSUFFICIENT_CREDIT') {
      return 'موجودی سرمایه یا صندوق برای این برداشت کافی نیست.';
    }
    if (failure.code == 'RECORD_IN_USE') {
      return 'این تراکنش وابستگی مالی دارد؛ ابتدا ثبت‌های وابسته را تعیین تکلیف کنید.';
    }
    if (failure.code == 'INVALID_STATE') {
      return 'وضعیت شریک یا تراکنش برای این عملیات مناسب نیست.';
    }
  }
  return SaleInvoiceFX.message(failure);
}

class PartnerMovementsScreen extends StatefulWidget {
  final String appId;
  final String? partnerId;
  final bool startAdd;
  const PartnerMovementsScreen({
    required this.appId,
    this.partnerId,
    this.startAdd = false,
    super.key,
  });
  @override
  State<PartnerMovementsScreen> createState() => _PartnerMovementsScreenState();
}

class _PartnerMovementsScreenController extends GetxController {
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  PartnerMovementsFX? fx;
  List<RemoteSupplier> partners = [];
  List<PartnerMovement> rows = [];
  RemoteSupplier? selected;
  String? filterId;
  String? error;
  bool loading = true, opening = false;
}

class _PartnerMovementsScreenState extends State<PartnerMovementsScreen> {
  late final _page = _PartnerMovementsScreenController();

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page._readGeneration++;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final realtimeContext = BusinessContext.forApp(widget.appId);
    if (realtimeContext != null) {
      _page._realtime = RealtimeWatch(
        RealtimeFX.forContext(realtimeContext),
        {'accounting.partner', 'accounting.partner-movement'},
        () async {
          await load(background: true);
        },
        busy: () => _page.loading || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page._readGeneration++;
              _page.loading = false;
              _page.rows = [];
              _page.partners = [];
              _page.selected = null;
              _page.update();
            }
          }
        },
      );
    }
    _page.filterId = widget.partnerId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await load();
      if (mounted && widget.startAdd && _page.error == null) await form();
    });
  }

  Future<void> load({bool background = false}) async {
    if (!mounted) return;
    final request = ++_page._readGeneration;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.rows = [];
      if (!background) _page.partners = [];
      if (!background) _page.selected = null;
      _page.update();
    }
    try {
      final context = BusinessContext.forApp(widget.appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= PartnerMovementsFX(context);
      await _page.fx!.authorize();
      await _page.fx!.restore();
      final list = await _page.fx!.partners();
      final partner = _page.filterId == null
          ? null
          : await _page.fx!.partner(_page.filterId!);
      final movements = await _page.fx!.movements(partnerId: _page.filterId);
      if (mounted && request == _page._readGeneration) {
        _page.partners = list;
        _page.selected = partner;
        _page.rows = movements;
      }
    } catch (failure) {
      if (mounted && request == _page._readGeneration) {
        _page.error = partnerMovementMessage(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted && request == _page._readGeneration) {
        {
          _page.loading = false;
          _page.update();
        }
      }
    }
  }

  Future<void> form({PartnerMovement? original}) async {
    if (_page.loading || _page.opening || _page.fx == null) return;
    {
      _page.opening = true;
      _page.update();
    }
    await Get.toNamed(
      nav_routes.RoutesName.PARTNER_MOVEMENT_FORM,
      arguments: {
        'fx': _page.fx!,
        'partnerId': original?.partnerId ?? _page.filterId,
        'original': original,
      },
      preventDuplicates: false,
    );
    if (mounted) {
      {
        _page.opening = false;
        _page.update();
      }
      await load();
    }
  }

  Future<void> details(PartnerMovement row) async {
    await MyBottomSheet.view(
      context,
      title: partnerMovementKinds[row.kind]!,
      child: (_) => Column(
        children: [
          Text(RemoteJson(row.json['partnerSnapshot']).text('name')),
          MyDivider(),
          Text('مبلغ: ${financialMoney(row.money('amount'))}'),
          Text(
            'تاریخ: ${DateConvertor.grigoriToJalali(row.json['occurredAt'] as String)}',
          ),
          Text(
            'مانده سرمایه پس از ثبت: ${financialMoney(row.money('capitalBalance'))}',
          ),
          Text(
            'مانده جاری پس از ثبت: ${financialMoney(row.money('currentBalance'))}',
          ),
          Text('دلیل: ${row.json['reason']}'),
          if (row.json['routing'] != null)
            Text(
              'صندوق/حساب: ${RemoteJson(row.json['routing']).text('fundName')}',
            ),
          if (row.json['assetDescription'] != null)
            Text('شرح آورده: ${row.json['assetDescription']}'),
          if (_page.fx!.has('reverse') &&
              _page.fx!.pending == null &&
              row.kind != 'REVERSAL' &&
              !_page.rows.any((r) => r.json['originalMovementId'] == row.id))
            MiniBTN(
              name: 'ثبت برگشت تراکنش',
              noFlex: true,
              icon: IconsaxPlusLinear.undo,
              onTap: () {
                Get.back();
                form(original: row);
              },
            ),
          BTN(name: 'بستن', onTap: () => Get.back()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_PartnerMovementsScreenController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final partnerItems = [
          const ItemValue(text: 'همه شرکا', data: null),
          ..._page.partners.map((p) => ItemValue(text: p.name, data: p.id)),
        ];
        return Main(
          initState: () async => '',
          header: Header.page(
            context,
            text: _page.selected?.name ?? 'سرمایه و گردش شرکا',
          ),
          floatingActionButton:
              !_page.loading &&
                  !_page.opening &&
                  _page.error == null &&
                  _page.fx?.pending == null &&
                  _page.fx?.has('transact') == true &&
                  _page.selected?.status != 'ARCHIVED'
              ? MyFAB(
                  icon: IconsaxPlusLinear.add,
                  text: 'واریز/برداشت جدید',
                  onTap: () => form(),
                )
              : null,
          child: (_) => Column(
            children: [
              if (_page.loading || _page.opening) const Loader(),
              if (_page.error != null) ...[
                Text(_page.error!),
                BTN(name: 'تلاش مجدد', onTap: load),
              ],
              if (!_page.loading && _page.error == null) ...[
                if (widget.partnerId == null)
                  Dropdown(
                    name: 'نمایش گردش شریک',
                    itemValue: true,
                    disable: _page.opening,
                    items_Value: partnerItems,
                    defaultValue: partnerItems
                        .where((p) => p.data == _page.filterId)
                        .firstOrNull,
                    onChange: (v) {
                      if (!_page.loading && !_page.opening) {
                        _page.filterId = (v as ItemValue).data as String?;
                        load();
                      }
                    },
                  ),
                if (_page.selected != null) ...[
                  Text(
                    'مانده سرمایه: ${financialMoney(_page.selected!.capitalBalance)}',
                  ),
                  Text(
                    'مانده جاری: ${financialMoney(_page.selected!.currentBalance)}',
                  ),
                  MyDivider(),
                ],
                if (_page.fx?.pending != null)
                  BTN(name: 'پیگیری ثبت قبلی', onTap: () => form()),
                Expanded(
                  child: _page.rows.isEmpty
                      ? EmptyList(
                          text: 'تراکنشی ثبت نشده است.',
                          icon: IconsaxPlusLinear.receipt,
                        )
                      : RefreshIndicator(
                          onRefresh: load,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 70),
                            itemCount: _page.rows.length,
                            itemBuilder: (context, index) {
                              final row = _page.rows[index];
                              return InkWell(
                                onTap: () => details(row),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                row.money('capitalDelta') +
                                                        row.money(
                                                          'currentDelta',
                                                        ) >=
                                                    0
                                                ? AppColors.blue
                                                : AppColors.yellow,
                                            child: Icon(
                                              row.money('capitalDelta') +
                                                          row.money(
                                                            'currentDelta',
                                                          ) >=
                                                      0
                                                  ? IconsaxPlusLinear
                                                        .card_receive
                                                  : IconsaxPlusLinear.card_send,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${partnerMovementKinds[row.kind]} — ${RemoteJson(row.json['partnerSnapshot']).text('name')}',
                                                ),
                                                Text(
                                                  financialMoney(
                                                    row.money('amount'),
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                  ),
                                                ),
                                                Text(
                                                  row.json['reason'] as String,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            DateConvertor.grigoriToJalali(
                                              row.json['occurredAt'] as String,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    EndLine(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class PartnerMovementForm extends StatefulWidget {
  final PartnerMovementsFX fx;
  final String? partnerId;
  final PartnerMovement? original;
  const PartnerMovementForm({
    required this.fx,
    this.partnerId,
    this.original,
    super.key,
  });
  @override
  State<PartnerMovementForm> createState() => _PartnerMovementFormState();
}

class _PartnerMovementFormController extends GetxController {
  final amount = TextEditingController(),
      date = TextEditingController(),
      reason = TextEditingController(),
      description = TextEditingController();
  final method = 'نقدی'.obs,
      confirmed = 'بله'.obs,
      valuation = 'خیر'.obs,
      debit = 'خیر'.obs;
  String kind = 'CAPITAL_IN';
  String? partnerId, fundId, error;
  List<RemoteSupplier> partners = [];
  List<SalePaymentTarget> targets = [];
  RemoteSupplier? partner;
  bool loading = true, saving = false, targetsLoading = false;
}

class _PartnerMovementFormState extends State<PartnerMovementForm> {
  late final _page = _PartnerMovementFormController();

  PartnerMovementsFX get fx => widget.fx;
  bool get reverse => widget.original != null;
  bool get noncash => _page.kind == 'NONCASH_CAPITAL_IN';
  bool get busy => _page.loading || _page.saving || _page.targetsLoading;
  String get methodCode =>
      _page.method.value == 'نقدی' ? 'CASH' : 'BANK_TRANSFER';
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
      _page.amount,
      _page.date,
      _page.reason,
      _page.description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.partner = null;
      _page.update();
    }
    try {
      await fx.authorize();
      await fx.restore();
      if (fx.pending != null) {
        _page.partner = fx.parsePartner(fx.pending!.before);
      } else {
        if (!fx.has(reverse ? 'reverse' : 'transact')) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        _page.partners = (await fx.partners())
            .where((p) => p.status == 'ACTIVE')
            .toList();
        _page.partnerId = widget.partnerId;
        if (_page.partnerId != null)
          _page.partner = await fx.partner(_page.partnerId!);
        if (!reverse && fx.access.has('accounting.treasury.use')) {
          try {
            _page.targets = await fx.targets(methodCode);
          } catch (failure) {
            if (mounted) {
              Alert.error(partnerMovementMessage(failure), context: context);
            }
          }
        }
      }
    } catch (failure) {
      if (mounted) {
        _page.error = partnerMovementMessage(failure);
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
      final rows = await fx.targets(methodCode);
      if (mounted) {
        _page.targets = rows;
        _page.update();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(partnerMovementMessage(failure), context: context);
      }
    } finally {
      if (mounted) {
        _page.targetsLoading = false;
        _page.update();
      }
    }
  }

  Future<void> save() async {
    if (busy || _page.error != null) return;
    var attempted = false;
    try {
      var command = fx.pending;
      if (command == null) {
        final why = _page.reason.text.trim();
        if (_page.partner == null ||
            _page.confirmed.value != 'بله' ||
            why.isEmpty ||
            why.length > 500) {
          throw const FormatException(
            'شریک، دلیل و اطلاعات تراکنش را کامل کنید.',
          );
        }
        final body = <String, dynamic>{'reason': why, 'fundsConfirmed': true};
        if (reverse) {
          body.addAll({
            'partnerMovementId': widget.original!.id,
            'expectedPartnerRevision': _page.partner!.revision,
          });
        } else {
          final value = int.tryParse(
            _page.amount.text
                .toEnglishDigit()
                .replaceAll(',', '')
                .replaceAll('٬', '')
                .trim(),
          );
          if (value == null ||
              value <= 0 ||
              value > 9007199254740991 ||
              _page.date.text.isEmpty) {
            throw const FormatException(
              'مبلغ مثبت به تومان و تاریخ واقعی را وارد کنید.',
            );
          }
          final on = DateConvertor.jalaliToGrigori(_page.date.text)
              .substring(0, 10);
          final occurred = DateTime.parse('${on}T00:00:00.000Z');
          if (occurred.isAfter(DateTime.now().toUtc())) {
            throw const FormatException('تاریخ نمی‌تواند آینده باشد.');
          }
          body.addAll({
            'partnerId': _page.partner!.id,
            'expectedRevision': _page.partner!.revision,
            'kind': _page.kind,
            'amount': value,
            'occurredAt': occurred.toIso8601String(),
          });
          if (noncash) {
            if (_page.valuation.value != 'بله' ||
                _page.description.text.trim().isEmpty ||
                _page.description.text.trim().length > 1000) {
              throw const FormatException(
                'شرح آورده و تأیید ارزش‌گذاری را کامل کنید.',
              );
            }
            body.addAll({
              'assetDescription': _page.description.text.trim(),
              'valuationConfirmed': true,
            });
          } else {
            if (!_page.targets.any(
              (t) => t.id == _page.fundId && t.accepts(methodCode),
            )) {
              throw const FormatException(
                'صندوق یا حساب معتبر را انتخاب کنید.',
              );
            }
            body.addAll({
              'method': methodCode,
              'routing': {'fundId': _page.fundId},
            });
            if (_page.kind == 'CURRENT_OUT' &&
                _page.partner!.currentBalance! - value < 0) {
              if (!fx.has('overdraw') || _page.debit.value != 'بله') {
                throw const FormatException(
                  'برداشت بیش از مانده جاری، مجوز و تأیید بدهکار شدن شریک لازم دارد.',
                );
              }
              body['allowDebitBalance'] = true;
            }
          }
        }
        command = PartnerMovementCommand(
          reverse ? 'reverse' : 'create',
          body,
          before: fx.snapshot(_page.partner!),
          original: widget.original?.json,
        );
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      await fx.send(command);
      if (mounted) {
        Alert.success('تراکنش شریک با موفقیت ثبت شد.');
        Get.back(result: true);
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          !attempted && failure is FormatException
              ? failure.message
              : partnerMovementMessage(failure),
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
  Widget build(BuildContext context) {
    return GetBuilder<_PartnerMovementFormController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final partnerItems = _page.partners
            .map((p) => ItemValue(text: p.name, data: p.id))
            .toList();
        final fundItems = _page.targets
            .map((t) => ItemValue(text: t.name, data: t.id))
            .toList();
        final kindItems = partnerMovementKinds.entries
            .where((e) => e.key != 'REVERSAL')
            .map((e) => ItemValue(text: e.value, data: e.key))
            .toList();
        return PopScope(
          canPop: !_page.saving,
          child: Main(
            initState: () async => '',
            header: Header.page(
              context,
              text: reverse ? 'برگشت تراکنش شریک' : 'واریز/برداشت شریک',
            ),
            child: (_) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (busy) const Loader(),
                if (_page.error != null) Text(_page.error!),
                if (!_page.loading && _page.error == null) ...[
                  if (_page.partner != null) ...[
                    Text(_page.partner!.name),
                    Text(
                      'مانده سرمایه: ${financialMoney(_page.partner!.capitalBalance)}',
                    ),
                    Text(
                      'مانده جاری: ${financialMoney(_page.partner!.currentBalance)}',
                    ),
                    MyDivider(),
                  ],
                  if (fx.pending != null) ...[
                    const Text(
                      'ثبت قبلی با همان مشخصات پیگیری می‌شود؛ دوباره وجه جابه‌جا نکنید.',
                    ),
                    Text('دلیل: ${fx.pending!.body['reason']}'),
                  ] else ...[
                    if (!reverse && widget.partnerId == null)
                      Dropdown(
                        name: 'شریک',
                        itemValue: true,
                        disable: busy,
                        items_Value: partnerItems,
                        defaultValue: partnerItems
                            .where((p) => p.data == _page.partnerId)
                            .firstOrNull,
                        onChange: (v) {
                          if (!busy) {
                            {
                              _page.partnerId = (v as ItemValue).data as String;
                              _page.partner = _page.partners.firstWhere(
                                (p) => p.id == _page.partnerId,
                              );
                              _page.update();
                            }
                          }
                        },
                      ),
                    if (reverse) ...[
                      Text(
                        'برگشت ${partnerMovementKinds[widget.original!.kind]} به مبلغ ${financialMoney(widget.original!.money('amount'))}',
                      ),
                      const Text(
                        'وجه یا دارایی باید واقعاً در جهت عکس جابه‌جا شده باشد. سند اصلی حذف نمی‌شود.',
                      ),
                    ] else ...[
                      Dropdown(
                        name: 'نوع تراکنش',
                        itemValue: true,
                        disable: busy,
                        items_Value: kindItems,
                        defaultValue: kindItems.firstWhere(
                          (i) => i.data == _page.kind,
                        ),
                        onChange: (v) {
                          if (!busy) {
                            {
                              _page.kind = (v as ItemValue).data as String;
                              _page.confirmed.value = 'بله';
                              _page.valuation.value = _page.debit.value = 'خیر';
                              _page.update();
                            }
                          }
                        },
                      ),
                      PriceInput(
                        controller: _page.amount,
                        name: 'مبلغ',
                        require: true,
                        readOnly: busy,
                      ),
                      DateInput(
                        controller: _page.date,
                        name: 'تاریخ تراکنش',
                        require: true,
                        enabled: !busy,
                        onChanged: (_) {},
                      ),
                      if (noncash) ...[
                        Input(
                          controller: _page.description,
                          name: 'شرح آورده غیرنقدی',
                          require: true,
                          maxLength: 1000,
                          readOnly: busy,
                        ),
                        const Text('ارزش‌گذاری آورده غیرنقدی را تأیید می‌کنم.'),
                        MyTab(
                          tab: ['خیر', 'بله'],
                          value: _page.valuation,
                          callback: (v) {
                            if (!busy) {
                              _page.valuation.value = v;
                              _page.update();
                            }
                          },
                        ),
                      ] else ...[
                        MyTab(
                          tab: [
                            'نقدی',
                            if (fx.access.canUseBank) 'واریز بانکی',
                          ],
                          value: _page.method,
                          callback: (v) => loadTargets(v as String),
                        ),
                        Dropdown(
                          name: 'صندوق یا حساب',
                          itemValue: true,
                          disable: busy,
                          items_Value: fundItems,
                          defaultValue: fundItems
                              .where((f) => f.data == _page.fundId)
                              .firstOrNull,
                          onChange: (v) =>
                              _page.fundId = (v as ItemValue).data as String,
                        ),
                        MiniBTN(
                          name: 'دریافت مجدد مقصدها',
                          icon: IconsaxPlusLinear.refresh,
                          noFlex: true,
                          onTap: busy
                              ? null
                              : () => loadTargets(_page.method.value),
                        ),
                        if (_page.kind == 'CURRENT_OUT' &&
                            fx.has('overdraw')) ...[
                          const Text(
                            'بدهکار شدن حساب جاری شریک را تأیید می‌کنم.',
                          ),
                          MyTab(
                            tab: ['خیر', 'بله'],
                            value: _page.debit,
                            callback: (v) {
                              if (!busy) {
                                _page.debit.value = v;
                                _page.update();
                              }
                            },
                          ),
                        ],
                      ],
                    ],
                    Input(
                      controller: _page.reason,
                      name: 'دلیل تراکنش',
                      require: true,
                      maxLength: 500,
                      readOnly: busy,
                    ),
                  ],
                  BTN(
                    key: const ValueKey('partner-movement-save'),
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

Widget buildPartnerMovementFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return PartnerMovementForm(
    fx: args.required<PartnerMovementsFX>('fx'),
    partnerId: args.optional<String>('partnerId'),
    original: args.optional<PartnerMovement>('original'),
  );
}

Widget buildPartnerMovementsRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return PartnerMovementsScreen(
    appId: args.required<String>('appId'),
    partnerId: args.optional<String>('partnerId'),
    startAdd: args.optional<bool>('startAdd') ?? false,
  );
}
