import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import '../reports/financial_screen.dart' show financialMoney;

class AssetDisposalForm extends StatefulWidget {
  final FixedAssetsFX fx;
  final String assetId;
  const AssetDisposalForm({required this.fx, required this.assetId, super.key});
  @override
  State<AssetDisposalForm> createState() => _AssetDisposalFormState();
}

class _AssetDisposalFormController extends GetxController {
  final kind = 'فروش'.obs,
      method = 'نقدی'.obs,
      confirmed = 'خیر'.obs,
      received = 'خیر'.obs;
  final date = TextEditingController(),
      reason = TextEditingController(),
      proceeds = TextEditingController(),
      buyer = TextEditingController(),
      reference = TextEditingController();
  RemoteFixedAsset? asset;
  List<SalePaymentTarget> targets = [];
  String? fundId, error;
  bool loading = true, saving = false, loadingTargets = false;
}

class _AssetDisposalFormState extends State<AssetDisposalForm> {
  late final _page = _AssetDisposalFormController();

  static const kinds = {'فروش': 'SALE', 'اسقاط': 'SCRAP', 'مفقودی': 'LOSS'};
  static const methods = {'نقدی': 'CASH', 'واریز بانکی': 'BANK_TRANSFER'};

  FixedAssetsFX get fx => widget.fx;
  bool get busy => _page.loading || _page.saving || _page.loadingTargets;
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
      _page.date,
      _page.reason,
      _page.proceeds,
      _page.buyer,
      _page.reference,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String message(Object failure) {
    if (failure is FormatException) {
      return 'پاسخ خروج دارایی معتبر نیست؛ درخواست قبلی را پیگیری کنید.';
    }
    if (failure is AuthError) {
      if (failure.code == 'FORBIDDEN') {
        return 'مجوز خروج دارایی یا دریافت وجه در مقصد انتخاب‌شده را ندارید.';
      }
      if (failure.code == 'RECORD_IN_USE') {
        return 'ابتدا چک‌های خریدِ در انتظار دارایی را تعیین تکلیف کنید.';
      }
      if (failure.code == 'IDEMPOTENCY_CONFLICT') {
        return 'ابتدا درخواست قبلی دارایی را پیگیری کنید.';
      }
      if (failure.code == 'REVISION_CONFLICT') {
        return 'اطلاعات دارایی تغییر کرده است؛ اطلاعات را تازه کنید.';
      }
    }
    return FinancialReportsFX.message(failure);
  }

  Future<void> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.asset = null;
      _page.targets = [];
      _page.fundId = null;
      _page.update();
    }
    try {
      await fx.authorize();
      await fx.restore();
      final pending = fx.pending;
      if (pending != null &&
          (pending.action != 'dispose' ||
              pending.body['fixedAssetId'] != widget.assetId)) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      // A committed disposal is already inactive: resume using the saved pre-operation snapshot.
      final row = pending == null
          ? await fx.detail(widget.assetId)
          : RemoteFixedAsset(pending.before);
      if (row.id != widget.assetId || !fx.canOperate('dispose', row)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (pending == null && fx.access.has('accounting.treasury.use')) {
        try {
          _page.targets = await fx.disposalTargets(
            methods[_page.method.value]!,
          );
        } catch (failure) {
          // A destination lookup failure must not prevent scrapping or loss without proceeds.
          if (mounted) Alert.error(message(failure), context: context);
        }
        fx.check();
      }
      if (mounted) {
        _page.asset = row;
        _page.update();
      }
    } catch (failure) {
      if (mounted) {
        _page.error = message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> loadTargets([String? selected]) async {
    if (busy) return;
    {
      _page.loadingTargets = true;
      _page.fundId = null;
      _page.targets = [];
      if (selected != null) _page.method.value = selected;
      _page.update();
    }
    try {
      final rows = await fx.disposalTargets(methods[_page.method.value]!);
      if (mounted) {
        _page.targets = rows;
        _page.update();
      }
    } catch (failure) {
      if (mounted) Alert.error(message(failure), context: context);
    } finally {
      if (mounted) {
        _page.loadingTargets = false;
        _page.update();
      }
    }
  }

  Future<void> save() async {
    if (busy || _page.asset == null || _page.error != null) return;
    var attempted = false;
    try {
      var command = fx.pending;
      if (command == null) {
        final why = _page.reason.text.trim();
        if (_page.confirmed.value != 'بله' ||
            why.isEmpty ||
            why.length > 1000 ||
            _page.date.text.isEmpty) {
          throw const FormatException(
            'تاریخ، دلیل و تأیید وقوع واقعی خروج دارایی را کامل کنید.',
          );
        }
        final on = DateConvertor.jalaliToGrigori(_page.date.text)
            .substring(0, 10);
        RemoteFixedAsset.day(on);
        if (on.compareTo(_page.asset!.json['financialThrough'] as String) < 0 ||
            on.compareTo(
                  DateTime.now().toUtc().toIso8601String().substring(0, 10),
                ) >
                0) {
          throw const FormatException(
            'تاریخ نباید آینده یا پیش از آخرین ثبت مالی دارایی باشد.',
          );
        }
        final body = <String, dynamic>{
          'fixedAssetId': _page.asset!.id,
          'expectedRevision': _page.asset!.revision,
          'kind': kinds[_page.kind.value],
          'effectiveOn': on,
          'reason': why,
          'confirmed': true,
        };
        if (_page.kind.value == 'فروش') {
          final value = int.tryParse(
            _page.proceeds.text
                .toEnglishDigit()
                .replaceAll(',', '')
                .replaceAll('٬', '')
                .trim(),
          );
          if (value == null ||
              value < 0 ||
              value > 9007199254740991 ||
              _page.buyer.text.trim().length > 200 ||
              _page.reference.text.trim().length > 200) {
            throw const FormatException(
              'مبلغ فروش را به تومان وارد کنید؛ برای فروش بدون عایدی، صفر وارد کنید. نام خریدار و شماره پیگیری حداکثر ۲۰۰ کاراکتر هستند.',
            );
          }
          body['proceeds'] = value;
          if (_page.buyer.text.trim().isNotEmpty) {
            body['buyerName'] = _page.buyer.text.trim();
          }
          if (value > 0) {
            if (_page.received.value != 'بله' ||
                !_page.targets.any(
                  (t) =>
                      t.id == _page.fundId &&
                      t.accepts(methods[_page.method.value]!),
                )) {
              throw const FormatException(
                'مقصد دریافت و دریافت واقعیِ کل مبلغ فروش را تأیید کنید.',
              );
            }
            body['receipt'] = {
              'method': methods[_page.method.value],
              'routing': {'fundId': _page.fundId},
              'confirmed': true,
              if (_page.reference.text.trim().isNotEmpty)
                'transactionReference': _page.reference.text.trim(),
            };
          }
        }
        command = AssetCommand('dispose', body, before: _page.asset!.json);
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      final gain = await fx.send(command);
      if (mounted) {
        Alert.success(
          'خروج دارایی ثبت شد؛ سود/زیان ثبت‌شده: ${financialMoney(gain)}',
        );
        Get.back(result: true);
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          !attempted && failure is FormatException
              ? failure.message
              : message(failure),
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
    return GetBuilder<_AssetDisposalFormController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final items = _page.targets
            .map((t) => ItemValue(text: t.name, data: t.id))
            .toList();
        return PopScope(
          canPop: !_page.saving,
          child: Main(
            initState: () async => '',
            header: Header.page(context, text: 'فروش یا خروج دارایی'),
            child: (_) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (busy) const Loader(),
                if (_page.error != null)
                  Text(_page.error!, textAlign: TextAlign.center),
                if (_page.asset != null) ...[
                  Text(_page.asset!.name, textAlign: TextAlign.center),
                  MyDivider(text: 'اطلاعات ثبت‌شده'),
                  Text(
                    'ارزش دفتری فعلی: ${financialMoney(_page.asset!.money('bookValue'))}',
                  ),
                  Text(
                    'بدهی خرید: ${financialMoney(_page.asset!.money('liabilityAmount'))}',
                  ),
                  const Text(
                    'بدهی خرید با خروج دارایی حذف نمی‌شود. استهلاک تا تاریخ خروج و سود یا زیان را سرور ثبت می‌کند.',
                  ),
                  if (fx.pending != null) ...[
                    const Text(
                      'نتیجه درخواست قبلی را با همان مشخصات پیگیری کنید؛ خروج یا دریافت وجه را دوباره ثبت نکنید.',
                    ),
                    Text(
                      'نوع: ${kinds.entries.firstWhere((e) => e.value == fx.pending!.body['kind']).key}',
                    ),
                    Text(
                      'تاریخ: ${DateConvertor.grigoriToJalali(fx.pending!.body['effectiveOn'] as String)}',
                    ),
                    if (fx.pending!.body.containsKey('proceeds'))
                      Text(
                        'عایدی: ${financialMoney(fx.pending!.body['proceeds'])}',
                      ),
                    Text('دلیل: ${fx.pending!.body['reason']}'),
                  ] else ...[
                    MyTab(
                      tab: kinds.keys.toList(),
                      value: _page.kind,
                      callback: (v) {
                        if (!busy) {
                          {
                            _page.kind.value = v;
                            _page.confirmed.value = _page.received.value =
                                'خیر';
                            _page.update();
                          }
                        }
                      },
                    ),
                    DateInput(
                      controller: _page.date,
                      name: 'تاریخ خروج',
                      require: true,
                      enabled: !busy,
                      onChanged: (_) {},
                    ),
                    if (_page.kind.value == 'فروش') ...[
                      PriceInput(
                        controller: _page.proceeds,
                        name: 'مبلغ واقعی فروش',
                        require: true,
                        readOnly: busy,
                      ),
                      Input(
                        controller: _page.buyer,
                        name: 'نام خریدار (اختیاری)',
                        maxLength: 200,
                        readOnly: busy,
                      ),
                      MyDivider(text: 'دریافت وجه فروش'),
                      const Text(
                        'برای مبلغ مثبت، کل وجه باید واقعاً دریافت شده باشد. دریافت چک یا فروش اعتباری در این عملیات پشتیبانی نمی‌شود.',
                      ),
                      MyTab(
                        tab: ['نقدی', if (fx.access.canUseBank) 'واریز بانکی'],
                        value: _page.method,
                        callback: (v) => loadTargets(v as String),
                      ),
                      Dropdown(
                        name: 'مقصد دریافت وجه',
                        itemValue: true,
                        disable: busy,
                        items_Value: items,
                        defaultValue: items
                            .where((i) => i.data == _page.fundId)
                            .firstOrNull,
                        onChange: (v) =>
                            _page.fundId = (v as ItemValue).data as String,
                      ),
                      if (_page.targets.isEmpty)
                        EmptyList(
                          text: 'مقصد دریافت در دسترس نیست؛ مبلغ مثبت بدون مقصد ثبت نمی‌شود.',
                        ),
                      MiniBTN(
                        name: 'دریافت مجدد مقصدها',
                        icon: IconsaxPlusLinear.refresh,
                        noFlex: true,
                        onTap: busy ? null : () => loadTargets(),
                      ),
                      Input(
                        controller: _page.reference,
                        name: 'شماره پیگیری دریافت (اختیاری)',
                        maxLength: 200,
                        readOnly: busy,
                      ),
                      const Text('کل مبلغ فروش را دریافت کرده‌ام.'),
                      MyTab(
                        tab: ['خیر', 'بله'],
                        value: _page.received,
                        callback: (v) {
                          if (!busy) {
                            _page.received.value = v;
                            _page.update();
                          }
                        },
                      ),
                    ],
                    MyDivider(text: 'تأیید خروج واقعی'),
                    Text(
                      'وقوع واقعی ${_page.kind.value} این دارایی را تأیید می‌کنم.',
                    ),
                    MyTab(
                      tab: ['خیر', 'بله'],
                      value: _page.confirmed,
                      callback: (v) {
                        if (!busy) {
                          _page.confirmed.value = v;
                          _page.update();
                        }
                      },
                    ),
                    Input(
                      controller: _page.reason,
                      name: 'دلیل خروج',
                      require: true,
                      maxLength: 1000,
                      readOnly: busy,
                    ),
                  ],
                  BTN(
                    key: const ValueKey('asset-dispose-save'),
                    name: fx.pending == null
                        ? 'ثبت نهایی خروج'
                        : 'پیگیری درخواست قبلی',
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

Widget buildAssetDisposalFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return AssetDisposalForm(
    fx: args.required<FixedAssetsFX>('fx'),
    assetId: args.required<String>('assetId'),
  );
}
