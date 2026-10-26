import 'package:mik_router/mik_router.dart' as nav_routes;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/models/business_branch.dart';

import 'controller.dart';
import '../product/warehouse/controller.dart';
import 'fund_item.dart';

import 'package:mik_data/source/remote/models/branch_fund.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/branches.dart';

class BranchManagementScreen extends StatefulWidget {
  final String appId;
  const BranchManagementScreen({required this.appId, super.key});
  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  late final c = BranchManagementController(
    appId: widget.appId,
    onNotice: (message, success) {
      if (!mounted) return;
      if (success) {
        Alert.success(message);
      } else {
        Alert.error(message, context: context);
      }
    },
  );
  final search = TextEditingController();
  @override
  void dispose() {
    c.onClose();
    search.dispose();
    super.dispose();
  }

  Future<Object> load() async {
    await c.load();
    return '';
  }

  Future<void> form({BusinessBranch? row}) async {
    await Get.toNamed(
      nav_routes.RoutesName.BRANCH_FORM,
      arguments: {'c': c, 'row': row},
      preventDuplicates: false,
    );
  }

  Future<void> details(BusinessBranch item) async {
    final row = await c.details(item.branchId);
    if (!mounted || row == null) return;
    final edit = await MyBottomSheet.view(
      context,
      title: row.name,
      child: (_) => Column(
        children: [
          SelectableText('شناسه: ${row.branchId}'),
          MyDivider(),
          Text('آدرس: ${row.address?['fullAddress'] ?? 'ثبت نشده'}'),
          Text(
            'وضعیت: ${row.status == 'ACTIVE'
                ? 'فعال'
                : row.status == 'SUSPENDED'
                ? 'تعلیق‌شده'
                : 'آرشیو'}',
          ),
          if (row.defaultWarehouseId != null)
            SelectableText('شناسه انبار پیش‌فرض: ${row.defaultWarehouseId}'),
          if (row.defaultWarehouseId == null)
            const Text('انبار پیش‌فرض انتخاب نشده است.'),
          MyDivider(),
          BTN(
            name: 'اتصال و مدیریت انبارهای شعبه',
            navigate: true,
            onTap: () async {
              final warehouses = WarehouseManagementController();
              await Get.toNamed(
                nav_routes.RoutesName.WAREHOUSE_MANAGEMENT,
                arguments: {'appId': widget.appId},
                preventDuplicates: false,
              );
              if (mounted) await c.load();
            },
          ),
          _BranchFunds(fx: c.fx!, branchId: row.branchId),
          BTN(
            name: 'مدیریت صندوق‌ها و حساب‌ها',
            navigate: true,
            onTap: () => Get.toNamed(
              nav_routes.RoutesName.TREASURY,
              arguments: {'appId': widget.appId, 'branchId': row.branchId},
              preventDuplicates: false,
            ),
          ),
          MyDivider(),
          if (c.fx!.canEdit(row.branchId))
            MiniBTN(
              name: 'ویرایش شعبه',
              noFlex: true,
              icon: IconsaxPlusLinear.edit_2,
              onTap: () => Get.back(result: true),
            ),
          BTN(name: 'بستن', onTap: () => Get.back()),
        ],
      ),
    );
    if (mounted && edit == true) await form(row: row);
  }

  @override
  Widget build(BuildContext context) => Main(
    initState: load,
    header: Header.page(context, text: 'شعب'),
    floatingActionButton: Obx(
      () => c.canCreate
          ? MyFAB(icon: IconsaxPlusLinear.add, text: 'شعبه جدید', onTap: form)
          : const SizedBox.shrink(),
    ),
    child: (_) => Column(
      children: [
        MySearchBar(
          type: SearchBarType.branch,
          controller: search,
          enableScanner: false,
          callback: (v) => c.query.value = v.toString(),
        ),
        Expanded(
          child: Obx(
            () => Column(
              children: [
                if (c.loading.value || c.saving.value)
                  const LinearProgressIndicator(),
                if (c.error.value != null) ...[
                  Text(c.error.value!, textAlign: TextAlign.center),
                  MiniBTN(
                    name: 'تلاش مجدد',
                    icon: IconsaxPlusLinear.refresh,
                    noFlex: true,
                    onTap: c.loading.value || c.saving.value ? null : c.load,
                  ),
                ],
                if (c.pending.value != null)
                  BTN(
                    name: 'ادامه درخواست قبلی',
                    disabled: c.saving.value,
                    onTap: form,
                  ),
                Expanded(
                  child: c.visible.isEmpty
                      ? c.loading.value || c.error.value != null
                            ? const SizedBox.shrink()
                            : EmptyList(
                                text: 'هیچ شعبه‌ای تعریف نشده است.',
                                icon: IconsaxPlusLinear.shop_remove,
                                child: MiniBTN(
                                  name: 'به‌روزرسانی',
                                  noFlex: true,
                                  icon: IconsaxPlusLinear.refresh,
                                  onTap: c.load,
                                ),
                              )
                      : RefreshIndicator(
                          onRefresh: c.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 80),
                            children: [
                              for (final row in c.visible)
                                Column(
                                  children: [
                                    InkWell(
                                      key: ValueKey(row.branchId),
                                      onTap: () => details(row),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                color: AppColors.boxBackground
                                                    .withValues(alpha: 0.07),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Icon(
                                                row.status == 'ACTIVE'
                                                    ? IconsaxPlusLinear.shop
                                                    : IconsaxPlusLinear
                                                          .shop_remove,
                                                size: 40,
                                                color: AppColors.disable,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    row.name,
                                                    maxLines: 1,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    'کد: ${row.code ?? row.branchId}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    row.address?['fullAddress']
                                                            as String? ??
                                                        'آدرس ثبت نشده',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
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
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _BranchFunds extends StatefulWidget {
  final BranchesFX fx;
  final String branchId;
  const _BranchFunds({required this.fx, required this.branchId});
  @override
  State<_BranchFunds> createState() => _BranchFundsState();
}

class _BranchFundsController extends GetxController {
  List<BranchFund> items = [];
  bool loading = true;
  String? error;
}

class _BranchFundsState extends State<_BranchFunds> {
  late final _page = _BranchFundsController();

  @override
  void initState() {
    super.initState();
    // Authorization updates shared reactive grants; start after the sheet builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<void> load() async {
    try {
      final rows = await widget.fx.funds(widget.branchId);
      if (mounted) {
        {
          _page.items = rows;
          _page.loading = false;
          _page.error = null;
          _page.update();
        }
      }
    } catch (failure) {
      if (!mounted) return;
      {
        _page.items = [];
        _page.loading = false;
        _page.error = failure is AuthError && failure.statusCode == 403
            ? 'مجوز مشاهده صندوق‌های این شعبه را ندارید.'
            : failure is FormatException
            ? 'پاسخ صندوق‌های شعبه معتبر نیست؛ دوباره تلاش کنید.'
            : BranchesFX.message(failure);
        _page.update();
      }
      Alert.error(_page.error!, context: context);
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_BranchFundsController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Column(
      children: [
        MyDivider(text: 'صندوق‌های شعبه'),
        if (_page.loading)
          const LinearProgressIndicator()
        else if (_page.error != null) ...[
          Text(_page.error!, textAlign: TextAlign.center),
          MiniBTN(
            name: 'دریافت مجدد صندوق‌ها',
            noFlex: true,
            icon: IconsaxPlusLinear.refresh,
            onTap: () {
              {
                _page.loading = true;
                _page.error = null;
                _page.update();
              }
              load();
            },
          ),
        ] else if (_page.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text('صندوق یا تنخواهی برای این شعبه تعریف نشده است.'),
          )
        else
          for (var i = 0; i < _page.items.length; i++)
            BranchFundItem(
              key: ValueKey(_page.items[i].id),
              item: _page.items[i],
              end: i < _page.items.length - 1,
            ),
      ],
    ),
  );
}

class _BranchForm extends StatefulWidget {
  final BranchManagementController c;
  final BusinessBranch? row;
  const _BranchForm({required this.c, this.row});
  @override
  State<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends State<_BranchForm> {
  late final name = TextEditingController(
    text:
        widget.c.pending.value?.body['name'] as String? ??
        widget.row?.name ??
        '',
  );
  late final address = TextEditingController(
    text:
        (widget.c.pending.value?.body['address'] as Map?)?['fullAddress']
            as String? ??
        widget.row?.address?['fullAddress'] as String? ??
        '',
  );
  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final result = await widget.c.save(
      name.text,
      address.text,
      row: widget.row,
    );
    if (mounted && result != null) Get.back();
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !widget.c.saving.value,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: widget.row == null && widget.c.pending.value?.id == null
              ? 'افزودن شعبه جدید'
              : 'ویرایش شعبه',
        ),
        child: (_) => Obx(
          () => Column(
            children: [
              if (widget.c.saving.value) const LinearProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Input(
                        key: const ValueKey('branch-name'),
                        controller: name,
                        name: 'نام‌شعبه',
                        require: true,
                        maxLength: 200,
                        readOnly:
                            widget.c.saving.value ||
                            widget.c.pending.value != null,
                      ),
                      Input(
                        key: const ValueKey('branch-address'),
                        controller: address,
                        name: 'آدرس',
                        maxLines: 2,
                        minLines: 2,
                        maxLength: 1000,
                        readOnly:
                            widget.c.saving.value ||
                            widget.c.pending.value != null,
                      ),
                      const SizedBox(height: 10),
                      MyDivider(text: 'دسترسی به انبار‌ها'),
                      const Text(
                        'پس از ثبت، اتصال انبارها و انبار پیش‌فرض را از جزئیات همین شعبه تنظیم کنید.',
                        textAlign: TextAlign.center,
                      ),
                      if (widget.c.error.value != null)
                        Text(
                          widget.c.error.value!,
                          textAlign: TextAlign.center,
                        ),
                      if (widget.c.pending.value != null)
                        const Text(
                          'پاسخ درخواست قبلی دریافت نشده است؛ همان اطلاعات دوباره ارسال می‌شود.',
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
              BTN(
                name: widget.c.pending.value != null
                    ? 'تلاش مجدد ثبت'
                    : widget.row == null
                    ? 'افزودن شعبه'
                    : 'ویرایش شعبه',
                disabled: widget.c.saving.value,
                onTap: save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget buildBranchFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _BranchForm(
    c: args.required<BranchManagementController>('c'),
    row: args.optional<BusinessBranch>('row'),
  );
}
