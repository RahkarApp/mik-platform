import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/partnership.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/partner_ownership.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

String ownershipMessage(Object failure) {
  if (failure is FormatException) {
    return 'پاسخ تنظیمات سهم معتبر نیست؛ اطلاعات را تازه یا ثبت قبلی را پیگیری کنید.';
  }
  if (failure is AuthError) {
    if (failure.code == 'FORBIDDEN') {
      return 'مجوز مشاهده یا مدیریت سهم شرکا را ندارید.';
    }
    if (failure.code == 'REVISION_CONFLICT') {
      return 'تنظیمات سهم تغییر کرده است؛ اطلاعات را دوباره دریافت کنید.';
    }
    if (failure.code == 'IDEMPOTENCY_CONFLICT') {
      return 'ابتدا ثبت قبلی سهم شرکا را پیگیری کنید.';
    }
    if (failure.code == 'BATCH_LIMIT') {
      return 'تعداد شرکای مالی از محدوده پشتیبانی‌شده سرور بیشتر است.';
    }
  }
  return SaleInvoiceFX.message(failure);
}

String ownershipPercent(int value) =>
    '${(value ~/ 100).toString()}.${(value % 100).toString().padLeft(2, '0')}٪';

class PartnerOwnershipScreen extends StatefulWidget {
  final String appId;
  const PartnerOwnershipScreen({required this.appId, super.key});
  @override
  State<PartnerOwnershipScreen> createState() => _PartnerOwnershipScreenState();
}

class _PartnerOwnershipScreenController extends GetxController {
  PartnerOwnershipFX? fx;
  PartnerOwnership? current;
  List<RemoteSupplier> partners = [];
  final inputs = <String, TextEditingController>{};
  final reason = TextEditingController();
  final mode = 'بر اساس آورده'.obs;
  bool loading = true, saving = false;
  String? error;
}

class _PartnerOwnershipScreenState extends State<PartnerOwnershipScreen> {
  late final _page = _PartnerOwnershipScreenController();

  bool get busy => _page.loading || _page.saving;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page.reason.dispose();
    for (final c in _page.inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  String partnerName(String id) =>
      _page.partners.where((p) => p.id == id).firstOrNull?.name ?? id;
  Future<void> load() async {
    if (_page.saving) return;
    {
      _page.loading = true;
      _page.error = null;
      _page.update();
    }
    try {
      final context = BusinessContext.forApp(widget.appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= PartnerOwnershipFX(context);
      _page.current = await _page.fx!.get();
      await _page.fx!.restore();
      _page.partners = await _page.fx!.partners.partners();
      for (final c in _page.inputs.values) {
        c.dispose();
      }
      _page.inputs.clear();
      final fixed = _page.current!.partnership?.mode == 'FIXED';
      _page.mode.value = fixed ? 'سهم ثابت' : 'بر اساس آورده';
      _page.reason.clear();
      for (final p in _page.partners.where((p) => p.status == 'ACTIVE')) {
        final share = fixed
            ? _page.current!.shares
                  .where((s) => s.text('partnerId') == p.id)
                  .firstOrNull
            : null;
        _page.inputs[p.id] = TextEditingController(
          text: share == null
              ? ''
              : ownershipPercent(share.number('basisPoints'))
                    .replaceAll('٪', ''),
        );
      }
    } catch (failure) {
      if (mounted) {
        _page.error = ownershipMessage(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  int points(String text) {
    final value = text.trim().toEnglishDigit().replaceAll('٫', '.');
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException(
        'درصد را از صفر تا ۱۰۰ با حداکثر دو رقم اعشار وارد کنید.',
      );
    }
    final parts = value.split('.');
    final result =
        int.parse(parts.first) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
    if (result > 10000) {
      throw const FormatException('درصد هر شریک نباید بیشتر از ۱۰۰ باشد.');
    }
    return result;
  }

  String get total {
    try {
      final sum = _page.inputs.values
          .where((c) => c.text.trim().isNotEmpty)
          .fold<int>(0, (s, c) => s + points(c.text));
      return 'جمع درصدها: ${ownershipPercent(sum)}';
    } on FormatException {
      return 'درصدهای واردشده را بررسی کنید.';
    }
  }

  Future<void> save() async {
    if (busy || _page.error != null) return;
    var attempted = false;
    try {
      var command = _page.fx!.pending;
      if (command == null) {
        final fixed = _page.mode.value == 'سهم ثابت';
        final allocations = <Map<String, dynamic>>[
          if (fixed)
            for (final entry in _page.inputs.entries)
              if (entry.value.text.trim().isNotEmpty)
                {
                  'partnerId': entry.key,
                  'basisPoints': points(entry.value.text),
                },
        ];
        if (fixed &&
            (allocations.isEmpty ||
                allocations.length > 100 ||
                allocations.fold<int>(
                      0,
                      (s, r) => s + (r['basisPoints'] as int),
                    ) !=
                    10000)) {
          throw const FormatException(
            'جمع سهم شرکای انتخاب‌شده باید دقیقاً ۱۰۰٪ باشد.',
          );
        }
        if (_page.reason.text.trim().isEmpty ||
            _page.reason.text.trim().length > 500) {
          throw const FormatException(
            'دلیل تنظیم سهم را وارد کنید (حداکثر ۵۰۰ حرف).',
          );
        }
        command = OwnershipCommand({
          'mode': fixed ? 'FIXED' : 'CONTRIBUTIONS',
          'allocations': allocations,
          'expectedRevision': _page.current!.partnership?.revision ?? 0,
          'reason': _page.reason.text.trim(),
        });
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      await _page.fx!.send(command);
      if (mounted) {
        // The mutation response verifies persistence; shares are read again from the server.
        Alert.success('تنظیمات سهم شرکا با موفقیت ثبت شد.');
      }
      if (mounted) {
        {
          _page.saving = false;
          _page.update();
        }
        await load();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          !attempted && failure is FormatException
              ? failure.message
              : ownershipMessage(failure),
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
  ) => GetBuilder<_PartnerOwnershipScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'سهم و مالکیت شرکا'),
        child: (_) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (busy) const Loader(),
            if (_page.error != null) Text(_page.error!),
            if (!_page.loading &&
                _page.error == null &&
                _page.current != null) ...[
              const Text(
                'این تنظیم برای کل کسب‌وکار است و مانده سرمایه یا گردش مالی شرکا را تغییر نمی‌دهد.',
              ),
              MyDivider(text: 'وضعیت فعلی'),
              Text(
                _page.current!.partnership == null
                    ? 'هنوز تنظیمی ثبت نشده؛ سهم‌های فعلی را سرور بر اساس آورده نمایش می‌دهد.'
                    : _page.current!.partnership!.mode == 'FIXED'
                    ? 'روش فعلی: سهم ثابت'
                    : 'روش فعلی: بر اساس آورده',
              ),
              if (_page.current!.shares.isEmpty)
                const Text('سهمی برای نمایش موجود نیست.'),
              for (final row in _page.current!.shares)
                Text(
                  '${partnerName(row.text('partnerId'))}: ${row.value['basisPoints'] == null ? 'تعیین‌نشده (سرمایه کل صفر است)' : ownershipPercent(row.number('basisPoints'))}',
                ),
              if (_page.current!.partnership != null)
                Text(
                  'دلیل آخرین تنظیم: ${_page.current!.partnership!.json['reason']}',
                ),
              if (_page.fx!.pending != null) ...[
                MyDivider(text: 'ثبت در انتظار پیگیری'),
                const Text(
                  'همان تنظیم قبلی پیگیری می‌شود؛ ثبت تازه‌ای ارسال نمی‌شود.',
                ),
                Text(
                  _page.fx!.pending!.body['mode'] == 'FIXED'
                      ? 'روش: سهم ثابت'
                      : 'روش: بر اساس آورده',
                ),
                for (final row in Partnership.shares(
                  _page.fx!.pending!.body['allocations'],
                  nullable: false,
                ))
                  Text(
                    '${partnerName(row.text('partnerId'))}: ${ownershipPercent(row.number('basisPoints'))}',
                  ),
                Text('دلیل: ${_page.fx!.pending!.body['reason']}'),
              ] else if (_page.fx!.canManage) ...[
                MyDivider(text: 'تنظیم سهم'),
                MyTab(
                  key: const ValueKey('ownership-mode'),
                  tab: ['بر اساس آورده', 'سهم ثابت'],
                  value: _page.mode,
                  callback: (v) {
                    if (!busy) {
                      _page.mode.value = v;
                      _page.update();
                    }
                  },
                ),
                if (_page.mode.value == 'سهم ثابت') ...[
                  const Text(
                    'برای شرکای موردنظر درصد وارد کنید؛ فیلد خالی یعنی بدون تخصیص. جمع باید دقیقاً ۱۰۰٪ باشد.',
                  ),
                  if (_page.inputs.isEmpty)
                    const Text('ابتدا شریک فعال تعریف کنید.'),
                  for (final entry in _page.inputs.entries)
                    Input(
                      controller: entry.value,
                      name: 'درصد ${partnerName(entry.key)}',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      readOnly: busy,
                      onChanged: (_) {
                        _page.update();
                      },
                    ),
                  Text(total),
                ] else
                  const Text(
                    'درصدها توسط سرور از مانده سرمایه شرکای فعال محاسبه می‌شوند؛ وقتی سرمایه کل صفر باشد درصدی تعیین نمی‌شود.',
                  ),
                Input(
                  controller: _page.reason,
                  name: 'دلیل تنظیم سهم',
                  require: true,
                  maxLength: 500,
                  readOnly: busy,
                ),
              ],
              if (_page.fx!.canManage)
                BTN(
                  key: const ValueKey('ownership-save'),
                  name: _page.fx!.pending == null
                      ? 'ثبت نهایی'
                      : 'پیگیری ثبت قبلی',
                  disabled: busy,
                  onTap: save,
                ),
            ],
            BTN(name: 'دریافت مجدد اطلاعات', disabled: busy, onTap: load),
          ],
        ),
      ),
    ),
  );
}

Widget buildPartnerOwnershipRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return PartnerOwnershipScreen(appId: args.required<String>('appId'));
}
