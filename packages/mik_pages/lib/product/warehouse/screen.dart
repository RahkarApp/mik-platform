import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/models/models.dart';

import 'controller.dart';

import 'package:mik_components/elements/input/branchInput.dart';
import 'package:mik_data/utils/fx/branches.dart';

class WarehouseManagementScreen extends StatefulWidget {
  final String appId;
  final String? branchId;
  final WarehouseManagementController controller;
  const WarehouseManagementScreen({
    required this.appId,
    this.branchId,
    required this.controller,
    super.key,
  });
  @override
  State<WarehouseManagementScreen> createState() =>
      _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState extends State<WarehouseManagementScreen> {
  WarehouseManagementController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.detach();
    c.onNotice = (message, success) {
      if (!mounted) return;
      if (success) {
        Alert.success(message);
      } else {
        Alert.error(message, context: context);
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.attach(widget.appId, branchId: widget.branchId);
    });
  }

  @override
  void dispose() {
    c.onNotice = null;
    c.detach();
    super.dispose();
  }

  Future<void> edit([BusinessWarehouse? row]) async {
    c.commandError.value = null;
    await MyBottomSheet.view(
      context,
      title: row == null ? 'افزودن انبار جدید' : 'ویرایش انبار',
      child: (_) => _WarehouseNameForm(c: c, item: row),
    );
  }

  Future<void> details(BusinessWarehouse item) async {
    await c.prepare(item);
    if (!mounted || c.error.value != null) return;
    await MyBottomSheet.view(
      context,
      title: item.name,
      child: (_) => Obx(() {
        final row = c.items
            .where((r) => r.warehouseId == item.warehouseId)
            .firstOrNull;
        if (row == null) return const Text('اطلاعات انبار در دسترس نیست.');
        final link = c.link(row);
        final branch = c.branch.value;
        return Column(
          children: [
            SelectableText('شناسه: ${row.warehouseId}'),
            Text('وضعیت: ${status(row.status)}'),
            MyDivider(),
            if (widget.branchId == null)
              BTN(
                name: 'موجودی و گردش کالا',
                navigate: true,
                onTap: () async {
                  Get.back();
                  await Get.toNamed(
                    nav_routes.RoutesName.WAREHOUSE_STOCK,
                    arguments: {'appId': widget.appId, 'warehouse': row},
                    preventDuplicates: false,
                  );
                  if (mounted) await c.load();
                },
              ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تعداد اقلام: نامشخص'),
                Text('تعداد کالاها: نامشخص'),
              ],
            ),
            MyDivider(text: 'ارتباط با شعبه'),
            Text(branch?.name ?? 'اطلاعات شعبه در دسترس نیست'),
            if (!c.linksAvailable.value)
              const Text('مجوز یا اطلاعات ارتباط انبار و شعبه در دسترس نیست.')
            else ...[
              Text(
                link == null
                    ? 'به شعبه انتخاب‌شده متصل نیست.'
                    : 'وضعیت ارتباط: ${status(link.status)}',
              ),
              if (link != null)
                Text(
                  'مشاهده: ${link.canReadStock ? 'مجاز' : 'غیرمجاز'}  |  ورود: ${link.canReceiveStock ? 'مجاز' : 'غیرمجاز'}  |  خروج: ${link.canIssueStock ? 'مجاز' : 'غیرمجاز'}',
                ),
            ],
            if (branch?.defaultWarehouseId == row.warehouseId)
              const Text('انبار پیش‌فرض شعبه'),
            if (c.commandError.value != null)
              Text(c.commandError.value!, textAlign: TextAlign.center),
            if (c.saving.value) const LinearProgressIndicator(),
            if (c.conflict.value)
              MiniBTN(
                name: 'دریافت نسخه جدید',
                icon: IconsaxPlusLinear.refresh,
                noFlex: true,
                onTap: () async {
                  Get.back();
                  await c.load();
                },
              ),
            Row(
              children: [
                MiniBTN(
                  name: 'ویرایش',
                  icon: IconsaxPlusLinear.edit_2,
                  onTap: c.canEdit(row)
                      ? () async {
                          Get.back();
                          await edit(row);
                        }
                      : null,
                ),
                MiniBTN(
                  name: 'انتقال کالاها',
                  icon: IconsaxPlusLinear.arrow_swap_horizontal,
                  onTap: row.status == 'ACTIVE'
                      ? () async {
                          Get.back();
                          await Get.toNamed(
                            nav_routes.RoutesName.WAREHOUSE_STOCK,
                            arguments: {
                              'appId': widget.appId,
                              'warehouse': row,
                              'transfer': true,
                            },
                            preventDuplicates: false,
                          );
                          if (mounted) await c.load();
                        }
                      : null,
                ),
                if (widget.branchId == null)
                  MiniBTN(
                    name: 'انبارگردانی',
                    icon: IconsaxPlusLinear.refresh_2,
                    onTap: () async {
                      Get.back();
                      await Get.toNamed(
                        nav_routes.RoutesName.WAREHOUSE_COUNT,
                        arguments: {'appId': widget.appId, 'warehouse': row},
                        preventDuplicates: false,
                      );
                      if (mounted) await c.load();
                    },
                  ),
                MiniBTN(
                  name: 'حذف انبار',
                  icon: IconsaxPlusLinear.trash,
                  onTap: null,
                ),
              ],
            ),
            MiniBTN(
              name: link == null ? 'اتصال به شعبه' : 'تنظیم دسترسی شعبه',
              icon: IconsaxPlusLinear.link,
              noFlex: true,
              onTap: c.canLink && row.status == 'ACTIVE'
                  ? () async {
                      Get.back();
                      await MyBottomSheet.view(
                        context,
                        title: 'دسترسی شعبه به انبار',
                        child: (_) => _WarehouseLinkForm(
                          c: c,
                          item: row,
                          appId: widget.appId,
                        ),
                      );
                      if (mounted) {
                        await c.attach(widget.appId, branchId: widget.branchId);
                      }
                    }
                  : null,
            ),
            MiniBTN(
              name: 'انتخاب به‌عنوان انبار پیش‌فرض',
              icon: IconsaxPlusLinear.tick_square,
              noFlex: true,
              onTap: c.canDefault(row)
                  ? () => Confirm.con(
                      context,
                      type: ConfirmType.CHANGE,
                      confirmText: 'تأیید',
                      subtext:
                          '«${row.name}» انبار پیش‌فرض شعبه «${branch!.name}» شود؟',
                      onTapConfirm: () async {
                        Get.back();
                        await c.setDefault(row);
                      },
                    )
                  : null,
            ),
            const Text(
              'حذف انبار در این مرحله فعال نیست.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }

  String status(String value) => switch (value) {
    'ACTIVE' => 'فعال',
    'SUSPENDED' => 'تعلیق‌شده',
    'ARCHIVED' => 'آرشیو',
    _ => value,
  };
  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !c.saving.value,
      child: Stack(
        children: [
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: SizedBox(
                  height: 45,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'انبارها',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              if (c.loading.value || c.saving.value)
                const LinearProgressIndicator(),
              if (c.error.value != null) ...[
                Text(c.error.value!, textAlign: TextAlign.center),
                MiniBTN(
                  name: 'تلاش مجدد',
                  icon: IconsaxPlusLinear.refresh,
                  noFlex: true,
                  onTap: c.loading.value ? null : c.load,
                ),
              ],
              if (c.commandError.value != null)
                Text(c.commandError.value!, textAlign: TextAlign.center),
              if (c.pending.value != null) ...[
                Text(
                  'درخواست قبلی: ${c.pending.value!.body['name'] ?? 'تنظیم ارتباط انبار و شعبه'}',
                ),
                BTN(
                  name: 'ادامه درخواست قبلی',
                  disabled: c.saving.value,
                  onTap: c.resume,
                ),
              ],
              Expanded(
                child: c.visible.isEmpty
                    ? c.loading.value || c.error.value != null
                          ? const SizedBox.shrink()
                          : EmptyList(
                              text: c.query.value.isEmpty
                                  ? 'هیچ انباری وجود ندارد!'
                                  : 'انباری با این مشخصات موجود نیست!',
                              icon: IconsaxPlusLinear.box,
                            )
                    : RefreshIndicator(
                        onRefresh: c.load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 65),
                          itemCount: c.visible.length,
                          itemBuilder: (context, index) {
                            final row = c.visible[index];
                            final link = c.link(row);
                            return InkWell(
                              key: ValueKey(row.warehouseId),
                              onTap: c.locked ? null : () => details(row),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: AppColors.boxBackground
                                              .withValues(alpha: 0.07),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Icon(
                                          link?.status == 'ACTIVE'
                                              ? IconsaxPlusBold.home_hashtag
                                              : IconsaxPlusLinear.home_hashtag,
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
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    row.name,
                                                    maxLines: 1,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 10,
                                                      ),
                                                  child: Text(
                                                    c.linksAvailable.value
                                                        ? link?.status ==
                                                                  'ACTIVE'
                                                              ? c
                                                                        .branch
                                                                        .value
                                                                        ?.name ??
                                                                    link!
                                                                        .branchId
                                                              : 'بدون اتصال فعال به شعبه'
                                                        : 'ارتباط شعبه نامشخص',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 15),
                                            const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('اقلام: نامشخص'),
                                                Text('تعداد: نامشخص'),
                                              ],
                                            ),
                                            if (c
                                                    .branch
                                                    .value
                                                    ?.defaultWarehouseId ==
                                                row.warehouseId)
                                              const Text('پیش‌فرض شعبه'),
                                            if (row.status != 'ACTIVE')
                                              Text(status(row.status)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  EndLine(),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          if (c.canCreate)
            Positioned(
              bottom: 1,
              right: 10,
              child: MyFAB(
                icon: IconsaxPlusLinear.add,
                text: 'انبار جدید',
                onTap: edit,
              ),
            ),
        ],
      ),
    ),
  );
}

class _WarehouseNameForm extends StatefulWidget {
  final WarehouseManagementController c;
  final BusinessWarehouse? item;
  const _WarehouseNameForm({required this.c, this.item});
  @override
  State<_WarehouseNameForm> createState() => _WarehouseNameFormState();
}

class _WarehouseNameFormState extends State<_WarehouseNameForm> {
  late final text = TextEditingController(text: widget.item?.name ?? '');
  late final status =
      (widget.item?.status == 'SUSPENDED'
              ? 'تعلیق‌شده'
              : widget.item?.status == 'ARCHIVED'
              ? 'آرشیو'
              : 'فعال')
          .obs;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final c = widget.c;
    return PopScope(
      canPop: !c.saving.value,
      child: Column(
        children: [
          Input(
            key: const ValueKey('warehouse-name'),
            controller: text,
            name: 'نام انبار',
            require: true,
            readOnly:
                c.saving.value || c.pending.value != null || c.conflict.value,
          ),
          if (widget.item != null)
            IgnorePointer(
              ignoring:
                  c.saving.value || c.pending.value != null || c.conflict.value,
              child: MyTab(
                tab: const ['فعال', 'تعلیق‌شده', 'آرشیو'],
                value: status,
                callback: (String value) => status.value = value,
              ),
            ),
          if (c.commandError.value != null)
            Text(c.commandError.value!, textAlign: TextAlign.center),
          if (c.conflict.value)
            MiniBTN(
              name: 'دریافت نسخه جدید',
              icon: IconsaxPlusLinear.refresh,
              noFlex: true,
              onTap: () async {
                Get.back();
                await c.load();
              },
            ),
          Row(
            children: [
              Flexible(
                child: BTN(
                  name: c.pending.value != null
                      ? 'تلاش مجدد'
                      : widget.item == null
                      ? 'افزودن انبار'
                      : 'ویرایش انبار',
                  disabled: c.saving.value || c.conflict.value,
                  onTap: () async {
                    final saved = c.pending.value != null
                        ? await c.resume()
                        : await c.rename(
                            text.text,
                            item: widget.item,
                            status: status.value == 'فعال'
                                ? 'ACTIVE'
                                : status.value == 'آرشیو'
                                ? 'ARCHIVED'
                                : 'SUSPENDED',
                          );
                    if (saved && context.mounted) Get.back();
                  },
                ),
              ),
              Flexible(
                child: BTN(
                  name: 'انصراف',
                  type: BTNType.cancel,
                  disabled: c.saving.value,
                  onTap: () => Get.back(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });
}

class _WarehouseLinkForm extends StatefulWidget {
  final WarehouseManagementController c;
  final BusinessWarehouse item;
  final String appId;
  const _WarehouseLinkForm({
    required this.c,
    required this.item,
    required this.appId,
  });
  @override
  State<_WarehouseLinkForm> createState() => _WarehouseLinkFormState();
}

class _WarehouseLinkFormController extends GetxController {
  _WarehouseLinkFormController(this.widget);
  _WarehouseLinkForm widget;
  late bool read = widget.c.link(widget.item)?.canReadStock ?? false;
  late bool receive = widget.c.link(widget.item)?.canReceiveStock ?? false;
  late bool issue = widget.c.link(widget.item)?.canIssueStock ?? false;
  late final status =
      (widget.c.link(widget.item)?.status == 'SUSPENDED'
              ? 'تعلیق‌شده'
              : widget.c.link(widget.item)?.status == 'ARCHIVED'
              ? 'آرشیو'
              : 'فعال')
          .obs;
  final branchName = TextEditingController();
  List<BusinessBranch> branches = [];
  bool branchesLoading = true;
}

class _WarehouseLinkFormState extends State<_WarehouseLinkForm> {
  late final _page = _WarehouseLinkFormController(widget);

  @override
  void initState() {
    super.initState();
    _page.branchName.text = widget.c.branch.value?.name ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final client = BranchesFX.forContext(widget.c.fx!.context);
        await client.authorize();
        final rows = await client.all();
        if (mounted) {
          _page.branches = rows;
          _page.update();
        }
      } catch (failure) {
        if (mounted) Alert.error(BranchesFX.message(failure), context: context);
      } finally {
        if (mounted) {
          _page.branchesLoading = false;
          _page.update();
        }
      }
    });
  }

  @override
  void dispose() {
    _page.branchName.dispose();
    super.dispose();
  }

  Future<void> selectBranch(String id) async {
    await widget.c.attach(widget.appId, branchId: id);
    if (!mounted) return;
    final link = widget.c.link(widget.item);
    {
      _page.read = link?.canReadStock ?? false;
      _page.receive = link?.canReceiveStock ?? false;
      _page.issue = link?.canIssueStock ?? false;
      _page.status.value = link?.status == 'SUSPENDED'
          ? 'تعلیق‌شده'
          : link?.status == 'ARCHIVED'
          ? 'آرشیو'
          : 'فعال';
      _page.update();
    }
  }

  @override
  Widget build(BuildContext context) =>
      GetBuilder<_WarehouseLinkFormController>(
        init: _page,
        global: false,
        dispose: (state) => state.controller?.onDelete(),
        builder: (_) => Obx(() {
          final c = widget.c;
          return PopScope(
            canPop: !c.saving.value,
            child: Column(
              children: [
                Text(widget.item.name),
                if (_page.branchesLoading || c.loading.value)
                  const LinearProgressIndicator(),
                BranchInput(
                  controller: _page.branchName,
                  name: 'شعبه',
                  remoteItems: _page.branches,
                  readOnly: _page.branchesLoading || c.locked,
                  onChanged: (id) => selectBranch(id as String),
                ),
                const Text(
                  'برای خرید، ارتباط فعال و مجوز ورود کالا لازم است. برای فروش، مجوز خروج کالا لازم است.',
                ),
                if (c.link(widget.item) != null)
                  IgnorePointer(
                    ignoring:
                        c.saving.value ||
                        c.pending.value != null ||
                        c.conflict.value,
                    child: MyTab(
                      tab: const ['فعال', 'تعلیق‌شده', 'آرشیو'],
                      value: _page.status,
                      callback: (String value) => _page.status.value = value,
                    ),
                  ),
                for (final entry in {
                  'مشاهده موجودی': _page.read,
                  'ورود کالا': _page.receive,
                  'خروج کالا': _page.issue,
                }.entries)
                  MiniBTN(
                    name: '${entry.key}: ${entry.value ? 'مجاز' : 'غیرمجاز'}',
                    noFlex: true,
                    icon: entry.value
                        ? IconsaxPlusLinear.tick_square
                        : IconsaxPlusLinear.close_square,
                    onTap:
                        c.saving.value ||
                            c.pending.value != null ||
                            c.conflict.value
                        ? null
                        : () {
                            if (entry.key == 'مشاهده موجودی')
                              _page.read = !_page.read;
                            if (entry.key == 'ورود کالا')
                              _page.receive = !_page.receive;
                            if (entry.key == 'خروج کالا')
                              _page.issue = !_page.issue;
                            _page.update();
                          },
                  ),
                if (c.commandError.value != null)
                  Text(c.commandError.value!, textAlign: TextAlign.center),
                if (c.conflict.value)
                  MiniBTN(
                    name: 'دریافت نسخه جدید',
                    noFlex: true,
                    icon: IconsaxPlusLinear.refresh,
                    onTap: () async {
                      Get.back();
                      await c.load();
                    },
                  ),
                Row(
                  children: [
                    Flexible(
                      child: BTN(
                        name: c.pending.value == null
                            ? 'ثبت اتصال'
                            : 'تلاش مجدد',
                        disabled:
                            c.saving.value ||
                            c.loading.value ||
                            c.conflict.value ||
                            c.error.value != null,
                        onTap: () async {
                          final saved = c.pending.value != null
                              ? await c.resume()
                              : await c.connect(
                                  widget.item,
                                  read: _page.read,
                                  receive: _page.receive,
                                  issue: _page.issue,
                                  status: _page.status.value == 'فعال'
                                      ? 'ACTIVE'
                                      : _page.status.value == 'آرشیو'
                                      ? 'ARCHIVED'
                                      : 'SUSPENDED',
                                );
                          if (saved && context.mounted) Get.back();
                        },
                      ),
                    ),
                    Flexible(
                      child: BTN(
                        name: 'انصراف',
                        type: BTNType.cancel,
                        disabled: c.saving.value,
                        onTap: () => Get.back(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      );

  @override
  void didUpdateWidget(covariant _WarehouseLinkForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}
