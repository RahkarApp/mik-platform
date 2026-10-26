import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_data/utils/fx/asset_payments.dart';
import 'package:mik_utils/public/date.dart';

import '../reports/financial_screen.dart' show financialMoney;

class FixedAssetsScreen extends StatefulWidget {
  final String appId;
  final String? assetId;
  const FixedAssetsScreen({required this.appId, this.assetId, super.key});
  @override
  State<FixedAssetsScreen> createState() => _FixedAssetsScreenState();
}

class _FixedAssetsScreenController extends GetxController {
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  FixedAssetsFX? fx;
  List<RemoteFixedAsset> rows = [];
  RemoteFixedAsset? item;
  bool loading = true, opening = false;
  String? error;
}

class _FixedAssetsScreenState extends State<FixedAssetsScreen> {
  late final _page = _FixedAssetsScreenController();

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
        {
          'accounting.fixed-asset',
          'accounting.asset-category',
          'accounting.asset-movement',
          'accounting.asset-payment',
          'accounting.asset-cheque-followup',
        },
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
              _page.item = null;
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

  Future<void> load({bool background = false}) async {
    if (!mounted) return;
    final request = ++_page._readGeneration;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.rows = [];
      if (!background) _page.item = null;
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= FixedAssetsFX(active);
      if (widget.assetId == null) {
        final result = await _page.fx!.list();
        await _page.fx!.restore();
        if (mounted && request == _page._readGeneration) {
          {
            _page.rows = result;
            _page.update();
          }
        }
      } else {
        final result = await _page.fx!.detail(widget.assetId!);
        await _page.fx!.restore();
        if (mounted && request == _page._readGeneration) {
          {
            _page.item = result;
            _page.update();
          }
        }
      }
    } catch (failure) {
      if (mounted && request == _page._readGeneration) {
        {
          _page.error = FinancialReportsFX.message(failure);
          _page.update();
        }
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

  Future<void> create({bool category = false}) async {
    if (_page.loading || _page.opening || _page.fx == null) return;
    final pending = _page.fx!.pending;
    _page.opening = true;
    late final bool? result;
    try {
      final args = <String, Object?>{'fx': _page.fx!};
      String route;
      if (pending?.action == 'dispose') {
        route = nav_routes.RoutesName.ASSET_DISPOSAL_FORM;
        args['assetId'] = pending!.body['fixedAssetId'] as String;
      } else if (pending?.action == 'repair') {
        route = nav_routes.RoutesName.ASSET_REPAIR_FORM;
        args['assetId'] = pending!.body['fixedAssetId'] as String;
      } else if (['update', 'transfer', 'custody'].contains(pending?.action)) {
        route = nav_routes.RoutesName.ASSET_EDIT_FORM;
        args.addAll({
          'assetId': pending!.body['fixedAssetId'] as String,
          'transfer': pending.action == 'transfer',
          'custody': pending.action == 'custody',
        });
      } else if (['commission', 'depreciate'].contains(pending?.action)) {
        route = nav_routes.RoutesName.ASSET_LIFECYCLE_FORM;
        args.addAll({
          'assetId': pending!.body['fixedAssetId'] as String,
          'action': pending.action,
        });
      } else {
        route = nav_routes.RoutesName.ASSET_CREATE_FORM;
        args['categoryOnly'] = pending != null
            ? pending.action == 'category'
            : category;
      }
      result = await Get.toNamed<dynamic>(
        route,
        arguments: args,
        preventDuplicates: false,
      );
    } finally {
      _page.opening = false;
    }
    if (mounted &&
        result == true &&
        pending?.action == 'transfer' &&
        widget.assetId != null) {
      Get.back();
      return;
    }
    if (mounted) await load();
  }

  Future<void> operate(String action, RemoteFixedAsset row) async {
    if (_page.loading || _page.opening) return;
    if (_page.fx!.pending != null) {
      await create();
      return;
    }
    _page.opening = true;
    late final bool? result;
    try {
      final args = <String, Object?>{'fx': _page.fx!, 'assetId': row.id};
      String route;
      if (action == 'dispose') {
        route = nav_routes.RoutesName.ASSET_DISPOSAL_FORM;
      } else if (action == 'repair') {
        route = nav_routes.RoutesName.ASSET_REPAIR_FORM;
      } else if (['update', 'transfer', 'custody'].contains(action)) {
        route = nav_routes.RoutesName.ASSET_EDIT_FORM;
        args.addAll({
          'transfer': action == 'transfer',
          'custody': action == 'custody',
        });
      } else {
        route = nav_routes.RoutesName.ASSET_LIFECYCLE_FORM;
        args['action'] = action;
      }
      result = await Get.toNamed<dynamic>(
        route,
        arguments: args,
        preventDuplicates: false,
      );
    } finally {
      _page.opening = false;
    }
    // The asset now belongs to the destination; keep the current selected branch.
    if (mounted && result == true && action == 'transfer') {
      Get.back();
      return;
    }
    if (mounted) await load();
  }

  Future<void> movements() async {
    if (_page.opening || _page.loading || _page.item == null) return;
    {
      _page.opening = true;
      _page.update();
    }
    try {
      final rows = await _page.fx!.movements(_page.item!.id);
      if (!mounted) return;
      {
        _page.opening = false;
        _page.update();
      }
      // End the BTN's request spinner once data arrives, before the sheet closes.
      MyBottomSheet.view(
        context,
        title: 'گردش دارایی',
        child: (controller) => Column(
          children: [
            const Text(
              'گردش‌های قابل مشاهده در این شعبه',
              textAlign: TextAlign.center,
            ),
            if (rows.isEmpty) const Text('گردشی در این شعبه ثبت نشده است.'),
            for (final row in rows) ...[
              pair('عملیات', assetMovementNames[row.kind]!),
              pair('تاریخ مؤثر', DateConvertor.grigoriToJalali(row.on)),
              pair('علت', row.reason),
              pair('ثبت مالی', row.financial ? 'بله' : 'خیر'),
              if (row.toBranchId != null) ...[
                SelectableText('شناسه شعبه مبدأ: ${row.branchId}'),
                SelectableText('شناسه شعبه مقصد: ${row.toBranchId}'),
              ],
              MyDivider(),
            ],
            BTN(name: 'بستن', onTap: () => Get.back()),
          ],
        ),
      );
    } catch (failure) {
      if (mounted) {
        {
          _page.item = null;
          _page.error = FinancialReportsFX.message(failure);
          _page.update();
        }
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.opening = false;
        _page.update();
      }
    }
  }

  Widget pair(String label, String value) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
  Widget details(RemoteFixedAsset row) => ListView(
    children: [
      pair('نام', row.name),
      pair('کد دارایی', row.code),
      pair('دسته‌بندی هنگام ثبت', row.category),
      pair('وضعیت', assetStatuses[row.status]!),
      pair('وضعیت پرداخت', assetPaymentStatuses[row.json['paymentStatus']]!),
      pair(
        'منشأ',
        const {
          'PURCHASE': 'خرید',
          'OPENING': 'مانده افتتاحیه',
          'CONTRIBUTION': 'آورده شریک',
        }[row.json['source']]!,
      ),
      for (final entry in const {
        'serialNumber': 'شماره سریال',
        'location': 'محل استقرار',
        'note': 'توضیحات',
      }.entries)
        if (row.json[entry.key] != null)
          pair(entry.value, row.json[entry.key] as String),
      if (row.json['supplierSnapshot'] != null)
        pair(
          'تأمین‌کننده هنگام ثبت',
          (row.json['supplierSnapshot'] as Map)['name'] as String,
        ),
      if (row.json['custodian'] != null)
        pair(
          'تحویل‌گیرنده',
          (row.json['custodian'] as Map)['displayName'] as String,
        ),
      MyDivider(text: 'اطلاعات مالی ثبت‌شده'),
      for (final entry in RemoteFixedAsset.amounts.entries)
        pair(entry.value, financialMoney(row.money(entry.key))),
      MyDivider(text: 'استهلاک و تاریخ‌ها'),
      pair(
        'روش استهلاک',
        row.json['depreciationMethod'] == 'NONE' ? 'بدون استهلاک' : 'خط مستقیم',
      ),
      if (row.json['usefulLifeMonths'] != null)
        pair('عمر مفید (ماه)', '${row.json['usefulLifeMonths']}'),
      for (final entry in RemoteFixedAsset.dates.entries)
        if (row.json[entry.key] != null)
          pair(
            entry.value,
            DateConvertor.grigoriToJalali(row.json[entry.key] as String),
          ),
      const Text(
        'ارزش دفتری و استهلاک، مطابق ثبت‌های انجام‌شده سرور هستند.',
        textAlign: TextAlign.center,
      ),
      BTN(name: 'گردش دارایی', disabled: _page.opening, onTap: movements),
      for (final action in const {
        'update': 'ویرایش مشخصات',
        'custody': 'تحویل‌گیرنده و محل استقرار',
        'repair': 'تعمیر و بهسازی',
        'dispose': 'فروش یا خروج دارایی',
        'transfer': 'انتقال به شعبه دیگر',
        'commission': 'شروع بهره‌برداری',
        'depreciate': 'ثبت استهلاک',
      }.entries)
        if (_page.fx!.canOperate(action.key, row))
          MiniBTN(
            name: action.value,
            noFlex: true,
            icon: IconsaxPlusLinear.setting_2,
            onTap: _page.opening ? null : () => operate(action.key, row),
          ),
      if (row.json['source'] == 'PURCHASE')
        MiniBTN(
          name: 'پرداخت‌ها و تسویه خرید',
          noFlex: true,
          icon: IconsaxPlusLinear.wallet,
          onTap: () async {
            await Get.toNamed<dynamic>(
              nav_routes.RoutesName.ASSET_PAYMENT,
              arguments: {
                'fx': AssetPaymentsFX(_page.fx!, row.id),
                'asset': row,
              },
              preventDuplicates: false,
            );
            if (mounted) await load();
          },
        ),
      SelectableText('شناسه دارایی: ${row.id}'),
    ],
  );
  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_FixedAssetsScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      floatingActionButton:
          widget.assetId == null &&
              _page.fx != null &&
              !_page.loading &&
              (_page.fx!.pending != null || _page.fx!.canCreate)
          ? MyFAB(
              text: _page.fx!.pending != null
                  ? 'ادامه درخواست قبلی'
                  : 'دارایی جدید',
              icon: IconsaxPlusLinear.add,
              onTap: create,
            )
          : null,
      header: Header.page(
        context,
        text: widget.assetId == null ? 'دارایی‌های ثابت' : 'جزئیات دارایی',
      ),
      child: (_) => Column(
        children: [
          if (widget.assetId != null && _page.fx?.pending != null)
            MiniBTN(
              name: 'ادامه درخواست قبلی',
              noFlex: true,
              icon: IconsaxPlusLinear.refresh,
              onTap: _page.loading || _page.opening ? null : create,
            ),
          if (widget.assetId == null && _page.fx?.canManageCategories == true)
            MiniBTN(
              name: 'دسته‌بندی جدید دارایی',
              noFlex: true,
              icon: IconsaxPlusLinear.add,
              onTap: _page.loading || _page.opening
                  ? null
                  : () => create(category: true),
            ),
          Text(
            'شعبه: ${_page.fx?.context.selectedBranch?.name ?? 'انتخاب نشده'}',
          ),
          if (_page.loading || _page.opening) const LinearProgressIndicator(),
          if (_page.error != null)
            Text(_page.error!, textAlign: TextAlign.center),
          MiniBTN(
            name: 'دریافت مجدد',
            icon: IconsaxPlusLinear.refresh,
            noFlex: true,
            onTap: _page.loading || _page.opening ? null : load,
          ),
          Expanded(
            child: widget.assetId != null
                ? _page.item == null
                      ? const SizedBox.shrink()
                      : details(_page.item!)
                : _page.rows.isEmpty
                ? _page.loading || _page.error != null
                      ? const SizedBox.shrink()
                      : EmptyList(
                          icon: IconsaxPlusLinear.box,
                          text: 'دارایی‌ای در این شعبه ثبت نشده است.',
                        )
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 70),
                      itemCount: _page.rows.length,
                      itemBuilder: (_, i) {
                        final row = _page.rows[i];
                        return Column(
                          children: [
                            InkWell(
                              key: ValueKey(row.id),
                              onTap: () async {
                                await Get.toNamed<dynamic>(
                                  nav_routes.RoutesName.FIXED_ASSETS,
                                  arguments: {
                                    'appId': widget.appId,
                                    'assetId': row.id,
                                  },
                                  preventDuplicates: false,
                                );
                                if (mounted) await load();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: Column(
                                  children: [
                                    pair(row.name, row.code),
                                    pair(
                                      'ارزش دفتری',
                                      financialMoney(row.money('bookValue')),
                                    ),
                                    pair(
                                      row.category,
                                      assetStatuses[row.status]!,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (i != _page.rows.length - 1) EndLine(),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

Widget buildFixedAssetsRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return FixedAssetsScreen(
    appId: args.required<String>('appId'),
    assetId: args.optional<String>('assetId'),
  );
}
