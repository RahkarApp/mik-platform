import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
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
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/source/remote/models/business_branch.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_data/utils/fx/personnel.dart';
import 'package:mik_data/source/remote/models/personnel.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_utils/public/date.dart';

class AssetEditForm extends StatefulWidget {
  final FixedAssetsFX fx;
  final String assetId;
  final bool transfer, custody;
  const AssetEditForm({
    required this.fx,
    required this.assetId,
    this.transfer = false,
    this.custody = false,
    super.key,
  });
  @override
  State<AssetEditForm> createState() => _AssetEditFormState();
}

class _AssetEditFormController extends GetxController {
  final inputs = {
    for (final key in _AssetEditFormState.fields.keys)
      key: TextEditingController(),
  };
  final reason = TextEditingController(),
      date = TextEditingController(),
      warranty = TextEditingController(),
      due = TextEditingController();
  RemoteFixedAsset? asset;
  List<AssetCategory> categories = [];
  List<BusinessBranch> branches = [];
  List<ItemValue> custodians = [];
  String? custodianId;
  String? categoryId, toBranchId, error;
  bool loading = true, saving = false;
}

class _AssetEditFormState extends State<AssetEditForm> {
  late final _page = _AssetEditFormController();

  static const fields = {
    'name': 'نام دارایی',
    'code': 'کد دارایی',
    'serialNumber': 'شماره سریال',
    'location': 'محل استقرار',
    'note': 'توضیحات',
  };

  FixedAssetsFX get fx => widget.fx;
  String get action => widget.custody
      ? 'custody'
      : widget.transfer
      ? 'transfer'
      : 'update';
  String get title => widget.custody
      ? 'تحویل‌گیرنده و محل استقرار'
      : widget.transfer
      ? 'انتقال دارایی'
      : 'ویرایش دارایی';
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
      ..._page.inputs.values,
      _page.reason,
      _page.date,
      _page.warranty,
      _page.due,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String message(Object failure) {
    if (failure is FormatException) {
      return 'پاسخ عملیات دارایی معتبر نیست؛ درخواست قبلی را پیگیری کنید.';
    }
    if (failure is AuthError) {
      if (failure.code == 'FORBIDDEN') {
        return widget.custody
            ? 'مجوز این عملیات را ندارید یا تحویل‌گیرنده به این شعبه دسترسی ندارد.'
            : 'مجوز ویرایش یا انتقال در شعبه مبدأ و مقصد را ندارید.';
      }
      if (failure.code == 'RECORD_IN_USE') {
        return 'ابتدا بدهی خرید و چک‌های در انتظار دارایی را تسویه کنید.';
      }
      if (failure.code == 'IDEMPOTENCY_CONFLICT') {
        return 'ابتدا درخواست قبلی دارایی را از فهرست دارایی‌ها پیگیری کنید.';
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
      _page.branches = [];
      _page.categories = [];
      _page.update();
    }
    try {
      await fx.authorize();
      await fx.restore();
      final pending = fx.pending;
      if (pending != null &&
          (pending.action != action ||
              pending.body['fixedAssetId'] != widget.assetId)) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      final row = pending == null
          ? await fx.detail(widget.assetId)
          : RemoteFixedAsset(pending.before);
      if (row.id != widget.assetId || !fx.canOperate(action, row)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (pending == null) {
        if (widget.custody) {
          final current = row.json['custodian'] as Map?;
          _page.custodianId = current?['membershipId'] as String?;
          final self = fx.context.session.business.membershipId;
          final choices = <String, String>{self: 'خودم'};
          if (current != null) {
            choices[_page.custodianId!] = current['displayName'] as String;
          }
          if (fx.access.has('business.personnel.read', business: true)) {
            final personnel = PersonnelFX.forContext(fx.context);
            await personnel.authorize();
            for (final person in await personnel.list(
              PersonnelResource.person,
            )) {
              if (person.status == 'ACTIVE') {
                choices[person.data['membershipId'] as String] = person.name;
              }
            }
          }
          fx.check();
          _page.custodians = [
            const ItemValue(text: 'بدون تحویل‌گیرنده', data: null),
            for (final entry in choices.entries)
              ItemValue(text: entry.value, data: entry.key),
          ];
          _page.inputs['location']!.text =
              row.json['location'] as String? ?? '';
        } else if (widget.transfer) {
          _page.branches = await fx.transferBranches();
        } else {
          if (fx.access.has('accounting.asset.read', business: true)) {
            _page.categories = await fx.categories();
          }
          for (final key in fields.keys) {
            _page.inputs[key]!.text = row.json[key] as String? ?? '';
          }
          _page.categoryId = row.json['assetCategoryId'] as String;
          _page.warranty.text = row.json['warrantyUntil'] == null
              ? ''
              : DateConvertor.grigoriToJalali(
                  row.json['warrantyUntil'] as String,
                );
          _page.due.text = row.json['dueOn'] == null
              ? ''
              : DateConvertor.grigoriToJalali(row.json['dueOn'] as String);
        }
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

  String day(TextEditingController c) {
    if (c.text.isEmpty) throw const FormatException('تاریخ را وارد کنید.');
    final result = DateConvertor.jalaliToGrigori(c.text).substring(0, 10);
    RemoteFixedAsset.day(result);
    return result;
  }

  Future<void> save() async {
    if (_page.saving ||
        _page.loading ||
        _page.error != null ||
        _page.asset == null)
      return;
    var attempted = false;
    try {
      var command = fx.pending;
      if (command == null) {
        final explanation = _page.reason.text.trim();
        if (explanation.isEmpty || explanation.length > 1000) {
          throw const FormatException('دلیل عملیات را وارد کنید.');
        }
        final body = <String, dynamic>{
          'fixedAssetId': _page.asset!.id,
          'expectedRevision': _page.asset!.revision,
          'reason': explanation,
        };
        if (widget.custody) {
          final place = _page.inputs['location']!.text.trim();
          if (!_page.custodians.any((c) => c.data == _page.custodianId)) {
            throw const FormatException('تحویل‌گیرنده را انتخاب کنید.');
          }
          body['custodianMembershipId'] = _page.custodianId;
          // Omitting location preserves it; the server does not accept clearing it here.
          if (place != (_page.asset!.json['location'] ?? '')) {
            if (place.isEmpty || place.length > 500) {
              throw const FormatException(
                'محل استقرار باید بین ۱ تا ۵۰۰ کاراکتر باشد.',
              );
            }
            body['location'] = place;
          }
          final prior = _page.asset!.json['custodian'] as Map?;
          if (_page.custodianId == prior?['membershipId'] &&
              !body.containsKey('location')) {
            throw const FormatException(
              'تحویل‌گیرنده یا محل استقرار تغییری نکرده است.',
            );
          }
        } else if (widget.transfer) {
          if (!_page.branches.any((b) => b.branchId == _page.toBranchId)) {
            throw const FormatException('شعبه مقصد فعال را انتخاب کنید.');
          }
          final on = day(_page.date),
              place = _page.inputs['location']!.text.trim();
          if (place.length > 500 ||
              on.compareTo(_page.asset!.json['financialThrough'] as String) <
                  0 ||
              on.compareTo(
                    DateTime.now().toUtc().toIso8601String().substring(0, 10),
                  ) >
                  0) {
            throw const FormatException(
              'تاریخ انتقال و محل مقصد را بررسی کنید.',
            );
          }
          body.addAll({
            'toBranchId': _page.toBranchId,
            'effectiveOn': on,
            if (place.isNotEmpty) 'location': place,
          });
        } else {
          for (final field in fields.keys) {
            final text = _page.inputs[field]!.text.trim(),
                previous = _page.asset!.json[field] as String? ?? '';
            if (text == previous) continue;
            if (text.isEmpty) {
              throw FormatException(
                '${fields[field]} در قرارداد فعلی قابل خالی‌کردن نیست.',
              );
            }
            final max = field == 'code'
                ? 64
                : field == 'location'
                ? 500
                : field == 'note'
                ? 1000
                : 200;
            if (text.length > max) {
              throw FormatException('طول ${fields[field]} بیش از حد مجاز است.');
            }
            body[field] = text;
          }
          if (_page.categoryId != _page.asset!.json['assetCategoryId']) {
            if (!_page.categories.any((c) => c.id == _page.categoryId)) {
              throw const FormatException('دسته‌بندی فعال را انتخاب کنید.');
            }
            body['assetCategoryId'] = _page.categoryId;
          }
          for (final field in {
            'warrantyUntil': _page.warranty,
            if (_page.asset!.json['source'] == 'PURCHASE') 'dueOn': _page.due,
          }.entries) {
            final value = field.value.text.isEmpty ? null : day(field.value);
            if (value != _page.asset!.json[field.key]) body[field.key] = value;
          }
          if (body.length == 3) {
            throw const FormatException('مشخصاتی تغییر نکرده است.');
          }
        }
        command = AssetCommand(action, body, before: _page.asset!.json);
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      await fx.send(command);
      if (mounted) {
        Alert.success(
          widget.custody
              ? 'تحویل‌گیرنده و محل استقرار ثبت شد.'
              : widget.transfer
              ? 'انتقال دارایی به شعبه مقصد ثبت شد.'
              : 'مشخصات دارایی به‌روز شد.',
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

  Widget dateInput(String label, TextEditingController c) => Column(
    children: [
      DateInput(
        controller: c,
        name: label,
        enabled: !_page.saving && !_page.loading,
        onChanged: (_) {
          _page.update();
        },
      ),
      if (c.text.isNotEmpty)
        MiniBTN(
          name: 'پاک کردن $label',
          icon: IconsaxPlusLinear.close_circle,
          noFlex: true,
          onTap: _page.saving || _page.loading
              ? null
              : () {
                  c.clear();
                  _page.update();
                },
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    return GetBuilder<_AssetEditFormController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final categoryItems = <ItemValue>[
          if (_page.asset != null &&
              !_page.categories.any((c) => c.id == _page.categoryId))
            ItemValue(text: _page.asset!.category, data: _page.categoryId),
          ..._page.categories.map((c) => ItemValue(text: c.name, data: c.id)),
        ];
        return PopScope(
          canPop: !_page.saving,
          child: Main(
            initState: () async => '',
            header: Header.page(context, text: title),
            child: (_) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_page.loading || _page.saving)
                  const LinearProgressIndicator(),
                if (_page.error != null)
                  Text(_page.error!, textAlign: TextAlign.center),
                if (_page.asset != null) ...[
                  Text(_page.asset!.name, textAlign: TextAlign.center),
                  MyDivider(),
                  if (fx.pending != null) ...[
                    const Text('درخواست قبلی با همان مشخصات پیگیری می‌شود.'),
                    for (final field in {
                      ...fields,
                      'custodianMembershipId': 'شناسه تحویل‌گیرنده',
                      'toBranchId': 'شناسه شعبه مقصد',
                      'effectiveOn': 'تاریخ انتقال',
                      'assetCategoryId': 'شناسه دسته‌بندی',
                      'warrantyUntil': 'پایان ضمانت',
                      'dueOn': 'سررسید',
                      'reason': 'دلیل',
                    }.entries)
                      if (fx.pending!.body.containsKey(field.key))
                        SelectableText(
                          '${field.value}: ${fx.pending!.body[field.key] ?? 'پاک شود'}',
                        ),
                  ] else if (widget.custody) ...[
                    Dropdown(
                      name: 'تحویل‌گیرنده',
                      itemValue: true,
                      disable: _page.saving,
                      items_Value: _page.custodians,
                      defaultValue: _page.custodians
                          .where((c) => c.data == _page.custodianId)
                          .firstOrNull,
                      onChange: (v) {
                        _page.custodianId = (v as ItemValue).data as String?;
                        _page.update();
                      },
                    ),
                    if (!fx.access.has(
                      'business.personnel.read',
                      business: true,
                    ))
                      const Text(
                        'برای نمایش سایر پرسنل، مجوز مشاهده پرسنل لازم است.',
                      ),
                    const Text(
                      'دسترسی تحویل‌گیرنده به این شعبه هنگام ثبت بررسی می‌شود.',
                    ),
                    Input(
                      controller: _page.inputs['location']!,
                      name: 'محل استقرار',
                      maxLength: 500,
                      readOnly: _page.saving,
                    ),
                    Input(
                      controller: _page.reason,
                      name: 'دلیل عملیات',
                      require: true,
                      maxLength: 1000,
                      readOnly: _page.saving,
                    ),
                  ] else if (widget.transfer) ...[
                    Text('شعبه مبدأ: ${fx.context.selectedBranch!.name}'),
                    const Text(
                      'ابتدا بدهی و چک‌های خرید باید تعیین تکلیف شوند. مجوز انتقال در هر دو شعبه لازم است.',
                    ),
                    Dropdown(
                      name: 'شعبه مقصد',
                      itemValue: true,
                      require: true,
                      disable: _page.saving,
                      items_Value: _page.branches
                          .map((b) => ItemValue(text: b.name, data: b.branchId))
                          .toList(),
                      onChange: (v) =>
                          _page.toBranchId = (v as ItemValue).data as String,
                    ),
                    if (_page.branches.isEmpty)
                      const Text('شعبه فعال دیگری در دسترس نیست.'),
                    DateInput(
                      controller: _page.date,
                      name: 'تاریخ مؤثر انتقال',
                      require: true,
                      enabled: !_page.saving,
                      onChanged: (_) {},
                    ),
                    Input(
                      controller: _page.inputs['location']!,
                      name: 'محل در شعبه مقصد (اختیاری)',
                      maxLength: 500,
                      readOnly: _page.saving,
                    ),
                    const Text(
                      'تحویل‌گیرنده قبلی با انتقال پاک می‌شود. اگر محل مقصد را خالی بگذارید، محل قبلی نیز پاک می‌شود. استهلاک تا تاریخ انتقال توسط سرور ثبت می‌شود.',
                    ),
                    Input(
                      controller: _page.reason,
                      name: 'دلیل عملیات',
                      require: true,
                      maxLength: 1000,
                      readOnly: _page.saving,
                    ),
                  ] else ...[
                    for (final field in fields.entries)
                      Input(
                        controller: _page.inputs[field.key]!,
                        name: field.value,
                        maxLength: field.key == 'code'
                            ? 64
                            : field.key == 'location'
                            ? 500
                            : field.key == 'note'
                            ? 1000
                            : 200,
                        readOnly: _page.saving,
                      ),
                    if (fx.access.has('accounting.asset.read', business: true))
                      Dropdown(
                        name: 'دسته‌بندی دارایی',
                        itemValue: true,
                        defaultValue: categoryItems
                            .where((c) => c.data == _page.categoryId)
                            .firstOrNull,
                        disable: _page.saving,
                        items_Value: categoryItems,
                        onChange: (v) =>
                            _page.categoryId = (v as ItemValue).data as String,
                      )
                    else
                      Text('دسته‌بندی: ${_page.asset!.category}'),
                    dateInput('پایان ضمانت', _page.warranty),
                    if (_page.asset!.json['source'] == 'PURCHASE')
                      dateInput('سررسید پرداخت', _page.due),
                    Input(
                      controller: _page.reason,
                      name: 'دلیل عملیات',
                      require: true,
                      maxLength: 1000,
                      readOnly: _page.saving,
                    ),
                  ],
                  BTN(
                    key: const ValueKey('asset-edit-save'),
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

Widget buildAssetEditFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return AssetEditForm(
    fx: args.required<FixedAssetsFX>('fx'),
    assetId: args.required<String>('assetId'),
    transfer: args.optional<bool>('transfer') ?? false,
    custody: args.optional<bool>('custody') ?? false,
  );
}
