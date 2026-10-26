import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/numInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/expense.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/expenses.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class AssetRepairForm extends StatefulWidget {
  final FixedAssetsFX fx;
  final String assetId;
  const AssetRepairForm({required this.fx, required this.assetId, super.key});
  @override
  State<AssetRepairForm> createState() => _AssetRepairFormState();
}

class _AssetRepairFormController extends GetxController {
  final title = TextEditingController(),
      amount = TextEditingController(),
      date = TextEditingController(),
      reason = TextEditingController(),
      months = TextEditingController();
  final kind = 'تعمیر عادی'.obs, confirmation = 'تأیید نمی‌کنم'.obs;
  RemoteFixedAsset? asset;
  List<ExpenseCategory> categories = [];
  List<RemoteSupplier> payees = [];
  String? categoryId, payeeId, status, error;
  bool loading = true, saving = false;
}

class _AssetRepairFormState extends State<AssetRepairForm> {
  late final _page = _AssetRepairFormController();

  FixedAssetsFX get fx => widget.fx;
  bool get capital => _page.kind.value == 'بهسازی سرمایه‌ای';
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
      _page.title,
      _page.amount,
      _page.date,
      _page.reason,
      _page.months,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String message(Object failure) {
    if (failure is FormatException) {
      return 'پاسخ ثبت تعمیر معتبر نیست؛ درخواست قبلی را پیگیری کنید.';
    }
    if (failure is AuthError && failure.code == 'IDEMPOTENCY_CONFLICT') {
      return 'ابتدا درخواست قبلی دارایی را پیگیری کنید.';
    }
    return ExpensesFX.message(failure);
  }

  Future<void> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.asset = null;
      _page.update();
    }
    try {
      await fx.authorize();
      await fx.restore();
      final pending = fx.pending;
      if (pending != null &&
          (pending.action != 'repair' ||
              pending.body['fixedAssetId'] != widget.assetId)) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      final row = pending == null
          ? await fx.detail(widget.assetId)
          : RemoteFixedAsset(pending.before);
      if (row.id != widget.assetId || !fx.canOperate('repair', row)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (pending == null) {
        final expenses = ExpensesFX(fx.context);
        await expenses.authorize();
        _page.categories = (await expenses.categories())
            .where((c) => c.status == 'ACTIVE')
            .toList();
        final suppliers = SuppliersFX.forContext(
          fx.context,
          type: AccountingPersonType.serviceProvider,
        );
        await suppliers.authorize();
        _page.payees = await suppliers.all();
        _page.status = row.status;
      }
      fx.check();
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

  Future<void> save() async {
    if (_page.loading ||
        _page.saving ||
        _page.asset == null ||
        _page.error != null)
      return;
    var attempted = false;
    try {
      var command = fx.pending;
      if (command == null) {
        final value = int.tryParse(
          _page.amount.text
              .toEnglishDigit()
              .replaceAll(',', '')
              .replaceAll('٬', '')
              .trim(),
        );
        final text = _page.title.text.trim(), why = _page.reason.text.trim();
        if (value == null ||
            value <= 0 ||
            value > 9007199254740991 ||
            text.isEmpty ||
            text.length > 200 ||
            why.isEmpty ||
            why.length > 1000 ||
            _page.date.text.isEmpty ||
            !_page.categories.any((c) => c.id == _page.categoryId) ||
            !_page.payees.any((p) => p.id == _page.payeeId)) {
          throw const FormatException(
            'عنوان، مبلغ مثبت به تومان، تاریخ، دسته‌بندی، سرویس‌دهنده و دلیل را کامل کنید.',
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
        if (capital && _page.confirmation.value != 'تأیید می‌کنم') {
          throw const FormatException(
            'سرمایه‌ای بودن هزینه بهسازی را تأیید کنید.',
          );
        }
        final life = _page.months.text.isEmpty
            ? null
            : int.tryParse(_page.months.text.toEnglishDigit());
        if (capital &&
            _page.months.text.isNotEmpty &&
            (life == null || life < 1 || life > 1200)) {
          throw const FormatException(
            'عمر مفید باقی‌مانده باید بین ۱ تا ۱۲۰۰ ماه باشد.',
          );
        }
        command = AssetCommand('repair', {
          'fixedAssetId': _page.asset!.id,
          'expectedRevision': _page.asset!.revision,
          'kind': capital ? 'CAPITALIZE' : 'ROUTINE',
          'title': text,
          'amount': value,
          'occurredOn': on,
          'categoryId': _page.categoryId,
          'payeeId': _page.payeeId,
          'reason': why,
          if (_page.status != _page.asset!.status) 'status': _page.status,
          if (capital) 'capitalizationConfirmed': true,
          if (capital &&
              _page.asset!.json['depreciationMethod'] != 'NONE' &&
              life != null)
            'remainingLifeMonths': life,
        }, before: _page.asset!.json);
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      await fx.send(command);
      if (mounted) {
        Alert.success(
          'عملیات دارایی و هزینه مرتبط ثبت شد؛ پرداخت از بخش هزینه‌ها قابل انجام است.',
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
    return GetBuilder<_AssetRepairFormController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final categoryItems = _page.categories
            .map((c) => ItemValue(text: c.name, data: c.id))
            .toList();
        final payeeItems = _page.payees
            .map((p) => ItemValue(text: p.name, data: p.id))
            .toList();
        final statusItems =
            (_page.asset?.json['inServiceOn'] == null
                    ? ['REGISTERED']
                    : ['IN_USE', 'UNDER_REPAIR'])
                .map((s) => ItemValue(text: assetStatuses[s]!, data: s))
                .toList();
        return PopScope(
          canPop: !_page.saving,
          child: Main(
            initState: () async => '',
            header: Header.page(context, text: 'تعمیر و بهسازی دارایی'),
            child: (_) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_page.loading || _page.saving) const Loader(),
                if (_page.error != null)
                  Text(_page.error!, textAlign: TextAlign.center),
                if (_page.asset != null) ...[
                  Text(_page.asset!.name, textAlign: TextAlign.center),
                  MyDivider(),
                  if (fx.pending != null) ...[
                    const Text(
                      'همان درخواست قبلی پیگیری می‌شود؛ دوباره هزینه ثبت نکنید.',
                    ),
                    for (final field in const {
                      'title': 'عنوان',
                      'kind': 'نوع',
                      'amount': 'مبلغ',
                      'occurredOn': 'تاریخ',
                      'reason': 'دلیل',
                    }.entries)
                      Text('${field.value}: ${fx.pending!.body[field.key]}'),
                  ] else ...[
                    MyTab(
                      tab: [
                        'تعمیر عادی',
                        if (fx.access.has('accounting.asset.capitalize'))
                          'بهسازی سرمایه‌ای',
                      ],
                      value: _page.kind,
                      callback: (v) => _page.saving
                          ? null
                          : (() {
                              _page.kind.value = v;
                              _page.confirmation.value = 'تأیید نمی‌کنم';
                              _page.update();
                            })(),
                    ),
                    Input(
                      controller: _page.title,
                      name: 'عنوان تعمیر یا بهسازی',
                      require: true,
                      maxLength: 200,
                      readOnly: _page.saving,
                    ),
                    PriceInput(
                      controller: _page.amount,
                      name: 'مبلغ هزینه',
                      require: true,
                      readOnly: _page.saving,
                    ),
                    DateInput(
                      controller: _page.date,
                      name: 'تاریخ انجام',
                      require: true,
                      enabled: !_page.saving,
                      onChanged: (_) {},
                    ),
                    Dropdown(
                      name: 'دسته‌بندی هزینه',
                      itemValue: true,
                      require: true,
                      disable: _page.saving,
                      items_Value: categoryItems,
                      defaultValue: categoryItems
                          .where((c) => c.data == _page.categoryId)
                          .firstOrNull,
                      onChange: (v) =>
                          _page.categoryId = (v as ItemValue).data as String,
                    ),
                    Dropdown(
                      name: 'سرویس‌دهنده',
                      itemValue: true,
                      require: true,
                      disable: _page.saving,
                      items_Value: payeeItems,
                      defaultValue: payeeItems
                          .where((p) => p.data == _page.payeeId)
                          .firstOrNull,
                      onChange: (v) =>
                          _page.payeeId = (v as ItemValue).data as String,
                    ),
                    if (_page.categories.isEmpty || _page.payees.isEmpty)
                      EmptyList(
                        text: 'ابتدا دسته‌بندی هزینه و سرویس‌دهنده فعال تعریف کنید.',
                      ),
                    Dropdown(
                      name: 'وضعیت دارایی پس از عملیات',
                      itemValue: true,
                      disable: _page.saving,
                      items_Value: statusItems,
                      defaultValue: statusItems
                          .where((s) => s.data == _page.status)
                          .firstOrNull,
                      onChange: (v) =>
                          _page.status = (v as ItemValue).data as String,
                    ),
                    if (capital) ...[
                      MyDivider(text: 'بهسازی سرمایه‌ای'),
                      const Text(
                        'این هزینه به بهای دارایی اضافه می‌شود و سرور استهلاک و برنامه باقی‌مانده را محاسبه می‌کند.',
                      ),
                      if (_page.asset!.json['depreciationMethod'] != 'NONE')
                        NumberInput(
                          controller: _page.months,
                          name: 'عمر مفید باقی‌مانده (ماه، اختیاری)',
                          readOnly: _page.saving,
                        ),
                      const Text(
                        'تأیید می‌کنم این هزینه واجد شرایط سرمایه‌ای شدن است.',
                      ),
                      MyTab(
                        tab: ['تأیید نمی‌کنم', 'تأیید می‌کنم'],
                        value: _page.confirmation,
                        callback: (v) => _page.saving
                            ? null
                            : (() {
                                _page.confirmation.value = v;
                                _page.update();
                              })(),
                      ),
                    ],
                    Input(
                      controller: _page.reason,
                      name: 'دلیل عملیات',
                      require: true,
                      maxLength: 1000,
                      readOnly: _page.saving,
                    ),
                    const Text(
                      'هزینه بدون پرداخت اولیه ثبت می‌شود؛ تسویه آن از بخش هزینه‌ها انجام می‌شود.',
                    ),
                  ],
                  BTN(
                    key: const ValueKey('asset-repair-save'),
                    name: fx.pending == null
                        ? 'ثبت نهایی'
                        : 'پیگیری درخواست قبلی',
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
        );
      },
    );
  }
}

Widget buildAssetRepairFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return AssetRepairForm(
    fx: args.required<FixedAssetsFX>('fx'),
    assetId: args.required<String>('assetId'),
  );
}
