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
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class AssetCreateForm extends StatefulWidget {
  final FixedAssetsFX fx;
  final bool categoryOnly;
  const AssetCreateForm({
    required this.fx,
    this.categoryOnly = false,
    super.key,
  });
  @override
  State<AssetCreateForm> createState() => _AssetCreateFormState();
}

class _AssetCreateFormController extends GetxController {
  final name = TextEditingController(),
      code = TextEditingController(),
      serial = TextEditingController(),
      location = TextEditingController(),
      note = TextEditingController(),
      cost = TextEditingController(),
      acquired = TextEditingController(),
      inService = TextEditingController(),
      due = TextEditingController(),
      months = TextEditingController(),
      residual = TextEditingController();
  final depreciation = 'بدون استهلاک'.obs, confirmed = 'خیر'.obs;
  List<AssetCategory> categories = [];
  List<RemoteSupplier> suppliers = [];
  String? categoryId, supplierId, error;
  bool loading = true, saving = false;
}

class _AssetCreateFormState extends State<AssetCreateForm> {
  late final _page = _AssetCreateFormController();

  FixedAssetsFX get fx => widget.fx;
  bool get categoryOnly =>
      fx.pending?.action == 'category' || widget.categoryOnly;
  static const pendingLabels = {
    'name': 'نام',
    'note': 'توضیحات',
    'code': 'کد دارایی',
    'serialNumber': 'شماره سریال',
    'location': 'محل استقرار',
    'assetCategoryId': 'شناسه دسته‌بندی',
    'supplierId': 'شناسه تأمین‌کننده',
    'cost': 'بهای خرید (تومان)',
    'acquiredOn': 'تاریخ تحصیل',
    'inServiceOn': 'شروع بهره‌برداری',
    'dueOn': 'سررسید پرداخت',
  };
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
      _page.name,
      _page.code,
      _page.serial,
      _page.location,
      _page.note,
      _page.cost,
      _page.acquired,
      _page.inService,
      _page.due,
      _page.months,
      _page.residual,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.update();
    }
    try {
      await fx.authorize();
      await fx.restore();
      if (fx.pending != null &&
          !['create', 'category'].contains(fx.pending!.action)) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      if (fx.pending == null && !categoryOnly) {
        final cats = await fx.categories();
        final people = SuppliersFX.forContext(fx.context);
        await people.authorize();
        final rows = await people.all();
        if (mounted) {
          {
            _page.categories = cats;
            _page.suppliers = rows;
            _page.update();
          }
        }
      }
    } catch (failure) {
      if (mounted) {
        _page.error = FinancialReportsFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  String day(TextEditingController c) {
    if (c.text.isEmpty) throw const FormatException('تاریخ را وارد کنید.');
    final result = DateConvertor.jalaliToGrigori(c.text).substring(0, 10);
    RemoteFixedAsset.day(result);
    return result;
  }

  int amount(TextEditingController c) {
    final value = int.tryParse(
      c.text
          .toEnglishDigit()
          .replaceAll('تومان', '')
          .replaceAll(',', '')
          .trim(),
    );
    if (value == null || value < 0 || value > 9007199254740991) {
      throw const FormatException('مبلغ را به‌درستی وارد کنید.');
    }
    return value;
  }

  Future<void> save() async {
    if (_page.saving || _page.loading) return;
    {
      _page.saving = true;
      _page.update();
    }
    try {
      AssetCommand? command = fx.pending;
      if (command == null) {
        final title = _page.name.text.trim(),
            description = _page.note.text.trim();
        if (title.isEmpty || title.length > 200 || description.length > 1000) {
          throw const FormatException('نام و توضیحات را بررسی کنید.');
        }
        final body = <String, dynamic>{
          'name': title,
          if (description.isNotEmpty) 'note': description,
        };
        if (!categoryOnly) {
          if (!_page.categories.any((c) => c.id == _page.categoryId) ||
              !_page.suppliers.any((s) => s.id == _page.supplierId)) {
            throw const FormatException(
              'دسته‌بندی و تأمین‌کننده فعال را انتخاب کنید.',
            );
          }
          final value = amount(_page.cost), on = day(_page.acquired);
          if (value <= 0 ||
              on.compareTo(
                    DateTime.now().toUtc().toIso8601String().substring(0, 10),
                  ) >
                  0) {
            throw const FormatException(
              'بهای خرید باید مثبت و تاریخ تحصیل حداکثر امروز باشد.',
            );
          }
          if (_page.confirmed.value != 'بله') {
            throw const FormatException(
              'خرید واقعی دارایی و مبلغ آن را تأیید کنید.',
            );
          }
          final plan = <String, dynamic>{'method': 'NONE'};
          if (_page.depreciation.value == 'خط مستقیم') {
            final life = int.tryParse(_page.months.text.toEnglishDigit());
            final scrap = amount(_page.residual);
            if (life == null || life < 1 || life > 1200 || scrap > value) {
              throw const FormatException(
                'عمر مفید و ارزش اسقاط را بررسی کنید.',
              );
            }
            plan.addAll({
              'method': 'STRAIGHT_LINE',
              'usefulLifeMonths': life,
              'residualValue': scrap,
            });
          }
          body.addAll({
            'source': 'PURCHASE',
            'assetCategoryId': _page.categoryId,
            'supplierId': _page.supplierId,
            'cost': value,
            'acquiredOn': on,
            'depreciation': plan,
            'confirmed': true,
          });
          for (final field in {
            'code': _page.code,
            'serialNumber': _page.serial,
            'location': _page.location,
          }.entries) {
            final text = field.value.text.trim();
            if (text.length >
                (field.key == 'code'
                    ? 64
                    : field.key == 'location'
                    ? 500
                    : 200)) {
              throw const FormatException(
                'طول مشخصات دارایی بیش از حد مجاز است.',
              );
            }
            if (text.isNotEmpty) body[field.key] = text;
          }
          if (_page.inService.text.isNotEmpty) {
            final start = day(_page.inService);
            if (start.compareTo(on) < 0 ||
                start.compareTo(
                      DateTime.now().toUtc().toIso8601String().substring(0, 10),
                    ) >
                    0) {
              throw const FormatException(
                'تاریخ بهره‌برداری باید از تحصیل تا امروز باشد.',
              );
            }
            body['inServiceOn'] = start;
          }
          if (_page.due.text.isNotEmpty) body['dueOn'] = day(_page.due);
        }
        command = AssetCommand(categoryOnly ? 'category' : 'create', body);
      }
      final wasCategory = command.action == 'category';
      await fx.send(command);
      if (mounted) {
        Alert.success(
          wasCategory
              ? 'دسته‌بندی دارایی ثبت شد.'
              : 'خرید دارایی با موفقیت ثبت شد؛ پرداختی ثبت نشده است.',
        );
        Get.back(result: true);
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          failure is FormatException
              ? failure.message
              : FinancialReportsFX.message(failure),
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

  Widget dateField(
    String label,
    TextEditingController c, {
    bool required = false,
  }) => Column(
    children: [
      DateInput(
        controller: c,
        name: label,
        require: required,
        onChanged: (_) {
          _page.update();
        },
      ),
      if (!required && c.text.isNotEmpty)
        MiniBTN(
          name: 'پاک کردن $label',
          noFlex: true,
          icon: IconsaxPlusLinear.close_circle,
          onTap: () {
            c.clear();
            _page.update();
          },
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => GetBuilder<_AssetCreateFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(
        context,
        text: categoryOnly ? 'دسته‌بندی جدید دارایی' : 'ثبت خرید دارایی',
      ),
      child: (_) => Column(
        children: [
          if (_page.loading || _page.saving) const LinearProgressIndicator(),
          if (_page.error != null) ...[
            Text(_page.error!),
            BTN(name: 'دریافت مجدد', disabled: _page.loading, onTap: load),
          ],
          Expanded(
            child: IgnorePointer(
              ignoring: _page.saving || _page.loading,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (fx.pending != null) ...[
                    const Text(
                      'نتیجه درخواست قبلی نامشخص است؛ همان درخواست با همان اطلاعات پیگیری می‌شود.',
                    ),
                    for (final entry in fx.pending!.body.entries)
                      if (pendingLabels.containsKey(entry.key))
                        SelectableText(
                          '${pendingLabels[entry.key]}: ${entry.value}',
                        ),
                    if (fx.pending!.action == 'create') ...[
                      Text(
                        'روش استهلاک: ${(fx.pending!.body['depreciation'] as Map)['method'] == 'NONE' ? 'بدون استهلاک' : 'خط مستقیم'}',
                      ),
                      if ((fx.pending!.body['depreciation'] as Map)['method'] ==
                          'STRAIGHT_LINE') ...[
                        Text(
                          'عمر مفید (ماه): ${(fx.pending!.body['depreciation'] as Map)['usefulLifeMonths']}',
                        ),
                        Text(
                          'ارزش اسقاط (تومان): ${(fx.pending!.body['depreciation'] as Map)['residualValue']}',
                        ),
                      ],
                      const Text(
                        'خرید واقعی دارایی با این مشخصات تأیید شده؛ پرداخت اولیه ندارد.',
                      ),
                    ],
                  ] else if (!_page.loading && _page.error == null) ...[
                    Input(
                      controller: _page.name,
                      name: categoryOnly ? 'نام دسته‌بندی' : 'نام دارایی',
                      require: true,
                      maxLength: 200,
                    ),
                    if (!categoryOnly) ...[
                      Dropdown(
                        name: 'دسته‌بندی دارایی',
                        require: true,
                        itemValue: true,
                        items_Value: _page.categories
                            .map((c) => ItemValue(text: c.name, data: c.id))
                            .toList(),
                        onChange: (v) =>
                            _page.categoryId = (v as ItemValue).data as String,
                      ),
                      Dropdown(
                        name: 'تأمین‌کننده',
                        require: true,
                        itemValue: true,
                        items_Value: _page.suppliers
                            .map((s) => ItemValue(text: s.name, data: s.id))
                            .toList(),
                        onChange: (v) =>
                            _page.supplierId = (v as ItemValue).data as String,
                      ),
                      if (_page.categories.isEmpty)
                        const Text('ابتدا دسته‌بندی دارایی را تعریف کنید.'),
                      if (_page.suppliers.isEmpty)
                        const Text('ابتدا تأمین‌کننده فعال تعریف کنید.'),
                      Input(
                        controller: _page.code,
                        name: 'کد دارایی (اختیاری)',
                        maxLength: 64,
                      ),
                      Input(
                        controller: _page.serial,
                        name: 'شماره سریال',
                        maxLength: 200,
                      ),
                      Input(
                        controller: _page.location,
                        name: 'محل استقرار',
                        maxLength: 500,
                      ),
                      PriceInput(
                        controller: _page.cost,
                        name: 'بهای خرید (تومان)',
                        currency: 'تومان',
                        require: true,
                      ),
                      dateField('تاریخ تحصیل', _page.acquired, required: true),
                      dateField('شروع بهره‌برداری', _page.inService),
                      dateField('سررسید پرداخت', _page.due),
                      MyDivider(text: 'استهلاک'),
                      MyTab(
                        tab: const ['بدون استهلاک', 'خط مستقیم'],
                        value: _page.depreciation,
                        callback: (v) {
                          _page.depreciation.value = v as String;
                          _page.update();
                        },
                      ),
                      if (_page.depreciation.value == 'خط مستقیم') ...[
                        Input(
                          controller: _page.months,
                          name: 'عمر مفید (ماه)',
                          keyboardType: TextInputType.number,
                          require: true,
                        ),
                        PriceInput(
                          controller: _page.residual,
                          name: 'ارزش اسقاط (تومان)',
                          currency: 'تومان',
                          require: true,
                        ),
                      ],
                    ],
                    Input(
                      controller: _page.note,
                      name: 'توضیحات',
                      maxLength: 1000,
                    ),
                    if (!categoryOnly) ...[
                      const Text(
                        'خرید واقعی دارایی و بهای آن را تأیید می‌کنم. کل مبلغ فعلاً پرداخت‌نشده ثبت می‌شود.',
                      ),
                      MyTab(
                        tab: const ['خیر', 'بله'],
                        value: _page.confirmed,
                        callback: (v) => _page.confirmed.value = v as String,
                      ),
                    ],
                  ],
                  BTN(
                    name: fx.pending == null
                        ? 'ثبت نهایی'
                        : 'پیگیری درخواست قبلی',
                    disabled:
                        _page.loading || _page.saving || _page.error != null,
                    onTap: save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildAssetCreateFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return AssetCreateForm(
    fx: args.required<FixedAssetsFX>('fx'),
    categoryOnly: args.optional<bool>('categoryOnly') ?? false,
  );
}
