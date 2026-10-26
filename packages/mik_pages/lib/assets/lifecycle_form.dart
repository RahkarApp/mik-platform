import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_utils/public/date.dart';

import '../reports/financial_screen.dart' show financialMoney;

class AssetLifecycleForm extends StatefulWidget {
  final FixedAssetsFX fx;
  final String assetId, action;
  const AssetLifecycleForm({
    required this.fx,
    required this.assetId,
    required this.action,
    super.key,
  });
  @override
  State<AssetLifecycleForm> createState() => _AssetLifecycleFormState();
}

class _AssetLifecycleFormController extends GetxController {
  final date = TextEditingController(), reason = TextEditingController();
  RemoteFixedAsset? asset;
  bool loading = true, saving = false;
  String? error;
}

class _AssetLifecycleFormState extends State<AssetLifecycleForm> {
  late final _page = _AssetLifecycleFormController();

  FixedAssetsFX get fx => widget.fx;
  bool get commission => widget.action == 'commission';
  String get title => commission ? 'شروع بهره‌برداری' : 'ثبت استهلاک';
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
    _page.reason.dispose();
    super.dispose();
  }

  Future<void> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.asset = null;
      _page.update();
    }
    try {
      if (!['commission', 'depreciate'].contains(widget.action)) {
        throw const FormatException('Invalid asset action');
      }
      await fx.authorize();
      await fx.restore();
      final pending = fx.pending;
      if (pending != null &&
          (pending.action != widget.action ||
              pending.body['fixedAssetId'] != widget.assetId)) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      // A lost response may already have changed the live state. Replay the saved request.
      final row = pending == null
          ? await fx.detail(widget.assetId)
          : RemoteFixedAsset(pending.before);
      if (row.id != widget.assetId ||
          row.branchId != fx.branchId ||
          row.businessId != fx.access.businessId ||
          !fx.canOperate(widget.action, row)) {
        throw const AuthError(403, 'FORBIDDEN');
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

  String message(Object failure) {
    if (failure is FormatException) {
      return 'اطلاعات عملیات دارایی معتبر نیست؛ درخواست قبلی را پیگیری یا اطلاعات را تازه کنید.';
    }
    if (failure is AuthError) {
      if (failure.code == 'IDEMPOTENCY_CONFLICT') {
        return 'ابتدا درخواست قبلی دارایی را از فهرست دارایی‌ها پیگیری کنید.';
      }
      if (failure.code == 'FORBIDDEN') {
        return 'دارایی در وضعیت مناسب نیست یا مجوز این عملیات را ندارید.';
      }
      if (failure.code == 'REVISION_CONFLICT') {
        return 'اطلاعات دارایی تغییر کرده است؛ اطلاعات را دوباره دریافت کنید.';
      }
      if (failure.code == 'INVALID_STATE') {
        return 'تاریخ یا وضعیت دارایی برای این عملیات مناسب نیست؛ اطلاعات را تازه کنید.';
      }
    }
    return FinancialReportsFX.message(failure);
  }

  Future<void> save() async {
    if (_page.loading ||
        _page.saving ||
        _page.asset == null ||
        _page.error != null)
      return;
    var attempted = false;
    try {
      AssetCommand? command = fx.pending;
      if (command == null) {
        if (_page.date.text.isEmpty ||
            _page.reason.text.trim().isEmpty ||
            _page.reason.text.trim().length > 1000) {
          throw const FormatException('تاریخ و دلیل عملیات را وارد کنید.');
        }
        final on = DateConvertor.jalaliToGrigori(_page.date.text)
            .substring(0, 10);
        RemoteFixedAsset.day(on);
        if (on.compareTo(_page.asset!.json['financialThrough'] as String) < 0 ||
            !commission &&
                on.compareTo(
                      _page.asset!.json['depreciatedThrough'] as String,
                    ) <
                    0 ||
            on.compareTo(
                  DateTime.now().toUtc().toIso8601String().substring(0, 10),
                ) >
                0) {
          throw const FormatException(
            'تاریخ نباید آینده یا پیش از آخرین ثبت مالی و استهلاک باشد.',
          );
        }
        command = AssetCommand(widget.action, {
          'fixedAssetId': _page.asset!.id,
          'expectedRevision': _page.asset!.revision,
          commission ? 'inServiceOn' : 'throughOn': on,
          'reason': _page.reason.text.trim(),
        }, before: _page.asset!.json);
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      final amount = await fx.send(command);
      if (mounted) {
        Alert.success(
          commission
              ? 'شروع بهره‌برداری دارایی ثبت شد.'
              : 'عملیات استهلاک انجام شد؛ مبلغ این بازه: ${financialMoney(amount)}',
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
  Widget build(
    BuildContext context,
  ) => GetBuilder<_AssetLifecycleFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: title),
        child: (_) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null)
              Text(_page.error!, textAlign: TextAlign.center),
            if (_page.asset != null) ...[
              Text(_page.asset!.name, textAlign: TextAlign.center),
              MyDivider(text: 'اطلاعات ثبت‌شده'),
              Text(
                'ارزش دفتری: ${financialMoney(_page.asset!.money('bookValue'))}',
              ),
              Text(
                'استهلاک انباشته: ${financialMoney(_page.asset!.money('accumulatedDepreciation'))}',
              ),
              Text(
                'آخرین تاریخ مالی: ${DateConvertor.grigoriToJalali(_page.asset!.json['financialThrough'] as String)}',
              ),
              if (!commission) ...[
                Text(
                  'استهلاک ثبت‌شده تا: ${DateConvertor.grigoriToJalali(_page.asset!.json['depreciatedThrough'] as String)}',
                ),
                const Text(
                  'تاریخ پایان انحصاری است؛ استهلاک تا روز قبل از تاریخ انتخاب‌شده محاسبه می‌شود. مبلغ قطعی را سرور محاسبه می‌کند.',
                ),
              ],
              if (fx.pending != null) ...[
                const Text(
                  'نتیجه درخواست قبلی نامشخص است؛ همان درخواست با همان مشخصات پیگیری می‌شود.',
                ),
                Text(
                  'تاریخ: ${DateConvertor.grigoriToJalali(fx.pending!.body[commission ? 'inServiceOn' : 'throughOn'] as String)}',
                ),
                Text('دلیل: ${fx.pending!.body['reason']}'),
              ] else ...[
                DateInput(
                  controller: _page.date,
                  name: commission
                      ? 'تاریخ شروع بهره‌برداری'
                      : 'تاریخ پایان انحصاری',
                  require: true,
                  enabled: !_page.loading && !_page.saving,
                  onChanged: (_) {},
                ),
                Input(
                  controller: _page.reason,
                  name: 'دلیل عملیات',
                  require: true,
                  maxLength: 1000,
                  readOnly: _page.loading || _page.saving,
                ),
              ],
              BTN(
                key: const ValueKey('asset-lifecycle-save'),
                name: fx.pending == null ? title : 'پیگیری درخواست قبلی',
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

Widget buildAssetLifecycleFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return AssetLifecycleForm(
    fx: args.required<FixedAssetsFX>('fx'),
    assetId: args.required<String>('assetId'),
    action: args.required<String>('action'),
  );
}
