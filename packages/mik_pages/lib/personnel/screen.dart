import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/permission.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_consts/svgIcon.dart';
import 'package:mik_data/source/remote/models/personnel.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import 'controller.dart';

const _employment = {
  'ACTIVE': 'فعال',
  'SUSPENDED': 'تعلیق',
  'ENDED': 'پایان همکاری',
};
const _statuses = {'ACTIVE': 'فعال', 'SUSPENDED': 'تعلیق', 'ARCHIVED': 'آرشیو'};

// Category membership and order come from server domain/resource; these are display translations only.
const _permissionGroups = {
  'pim.product': 'محصولات',
  'pim.attribute': 'ویژگی محصولات',
  'pim.price': 'قیمت‌گذاری محصولات',
  'ucrm.customer': 'مشتریان',
  'ucrm.interaction': 'CRM',
  'accounting.sale': 'فاکتور فروش',
  'accounting.proforma': 'پیش‌فاکتور',
  'accounting.supplier': 'تامین‌کنندگان',
  'accounting.purchase': 'فاکتور خرید',
  'accounting.service-provider': 'سرویس‌دهندگان',
  'accounting.expense': 'هزینه‌ها',
  'accounting.cheque': 'چک‌ها',
  'business.warehouse': 'انبارها',
  'accounting.distribution': 'توزیع',
  'business.personnel': 'میک‌یار',
  'business.role': 'سطوح دسترسی',
  'accounting.report': 'گزارشات',
  'notification.notification': 'اطلاع‌رسانی',
  'accounting.billing': 'سایر',
  'pim.brand': 'برندها',
  'pim.variant': 'تنوع محصولات',
  'business.business': 'کسب‌وکار',
  'business.branch': 'شعبه‌ها',
  'business.branch-access': 'ارتباط شعبه و انبار',
  'business.channel-warehouse-access': 'دسترسی کانال‌ها به انبار',
  'business.work-shift': 'شیفت‌های کاری',
  'business.work-plan': 'برنامه‌های کاری',
  'business.attendance': 'حضور و غیاب',
  'inventory.stock': 'موجودی کالا',
  'inventory.valuation': 'ارزش موجودی',
  'inventory.kardex': 'کاردکس کالا',
  'inventory.reservation': 'رزرو موجودی',
  'inventory.commitment': 'تعهد موجودی',
  'accounting.account': 'حساب طرف حساب',
  'accounting.payment': 'دریافت و پرداخت',
  'accounting.invoice': 'فاکتورها',
  'accounting.presale': 'پیش‌فروش',
  'accounting.sale-return': 'برگشت از فروش',
  'accounting.purchase-return': 'برگشت از خرید',
  'accounting.treasury': 'خزانه',
  'accounting.bank': 'بانک‌ها',
  'accounting.terminal': 'پایانه‌ها',
  'accounting.ledger': 'دفتر حسابداری',
  'accounting.partner': 'شرکا',
  'accounting.loan': 'وام‌ها',
  'accounting.cash-shift': 'شیفت صندوق',
  'accounting.cheque-register': 'دفتر چک',
  'accounting.bank-reconciliation': 'مغایرت‌گیری بانکی',
  'accounting.asset': 'اموال و دارایی‌های ثابت',
  'accounting.chart': 'سرفصل حساب‌ها',
  'accounting.adjustment': 'اسناد اصلاحی',
  'accounting.advance': 'پیش‌پرداخت و پیش‌دریافت',
  'accounting.fiscal': 'سال و دوره‌های مالی',
  'ucrm.group': 'گروه‌های مشتری',
  'ucrm.tag': 'برچسب‌های مشتری',
  'ucrm.followup': 'پیگیری مشتریان',
  'shop.store': 'فروشگاه‌ها',
  'shop.publication': 'انتشار کالا در فروشگاه',
  'shop.shipping': 'ارسال فروشگاه',
  'shop.sync': 'همگام‌سازی فروشگاه',
  'payment.payment': 'پرداخت آنلاین',
  'payment.gateway': 'درگاه پرداخت',
  'media.file': 'فایل‌ها و ضمیمه‌ها',
};

class PersonnelScreen extends StatefulWidget {
  final String appId;
  final int initialTab;
  final bool initialCreate;
  final String? initialNotice;
  const PersonnelScreen({
    required this.appId,
    this.initialTab = 0,
    this.initialCreate = false,
    this.initialNotice,
    super.key,
  });
  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  late final c = PersonnelController(
    appId: widget.appId,
    onNotice: (message, ok) {
      if (!mounted) return;
      if (ok) {
        Alert.success(message);
      } else {
        Alert.error(message, context: context);
      }
    },
  );
  bool opened = false;
  @override
  void initState() {
    super.initState();
    c.tab.value = widget.initialTab;
  }

  Future<Object> load() async {
    await c.load();
    if (mounted && !opened) {
      opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialNotice != null) {
          Alert.error(widget.initialNotice!, context: context);
        }
        if (widget.initialCreate && c.canWrite(c.resource)) form();
      });
    }
    return '';
  }

  @override
  void dispose() {
    c.onClose();
    super.dispose();
  }

  Future<void> form({PersonnelEntry? item}) async {
    // The named router returns Route<dynamic>; check the result after awaiting it.
    final (PersonnelEntry, bool)? result = await Get.toNamed<dynamic>(
      nav_routes.RoutesName.PERSONNEL_FORM,
      arguments: {
        'c': c,
        'resource': item?.resource ?? c.resource,
        'item': item,
      },
      preventDuplicates: false,
    );
    if (mounted && result?.$2 == true) await showAccess(result!.$1);
  }

  Future<void> showAccess(PersonnelEntry item) async {
    if (!c.canWrite(PersonnelResource.access)) {
      Alert.error('مجوز تعیین سطح دسترسی را ندارید.', context: context);
      return;
    }
    await Get.toNamed<dynamic>(
      nav_routes.RoutesName.PERSONNEL_ACCESS,
      arguments: {'c': c, 'person': item},
      preventDuplicates: false,
    );
  }

  Future<void> assign(PersonnelEntry row) async {
    final item = await c.details(row);
    if (mounted && item != null) await showAccess(item);
  }

  Future<void> details(PersonnelEntry row) async {
    final item = await c.details(row);
    if (!mounted || item == null) return;
    await MyBottomSheet.view(
      context,
      title: item.name,
      child: (_) => Column(
        children: [
          Text(
            'وضعیت: ${(item.resource == PersonnelResource.person ? _employment : _statuses)[item.status]}',
          ),
          MyDivider(),
          if (item.resource == PersonnelResource.person) ...[
            Text('کد پرسنلی: ${item.data['personnelCode'] ?? 'ثبت نشده'}'),
            Text('سمت: ${item.data['jobTitle'] ?? 'ثبت نشده'}'),
          ] else ...[
            Text('توضیحات: ${item.data['description'] ?? 'ثبت نشده'}'),
            Text(
              'تعداد مجوزها: ${(item.data['permissionCodes'] as List).length}',
            ),
          ],
          if (c.canWrite(item.resource, update: true))
            MiniBTN(
              name: 'ویرایش',
              icon: IconsaxPlusLinear.edit_2,
              noFlex: true,
              onTap: () {
                Get.back();
                form(item: item);
              },
            ),
          if (item.resource == PersonnelResource.person &&
              c.canWrite(PersonnelResource.access))
            MiniBTN(
              name: 'سطح دسترسی',
              icon: IconsaxPlusLinear.lock,
              noFlex: true,
              onTap: () {
                Get.back();
                showAccess(item);
              },
            ),
          BTN(name: 'بستن', onTap: () => Get.back()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Main(
    initState: load,
    header: Header.page(context, text: 'میک‌یاران/پرسنل'),
    floatingActionButton: Obx(
      () => c.canWrite(c.resource)
          ? MyFAB(
              icon: IconsaxPlusLinear.add,
              text: c.tab.value == 0 ? 'میک‌یار جدید' : 'سطح دسترسی جدید',
              onTap: form,
            )
          : const SizedBox.shrink(),
    ),
    child: (_) => Obx(
      () => Column(
        children: [
          IgnorePointer(
            ignoring: c.loading.value || c.saving.value,
            child: MyTabBar(
              tabs: const ['افراد', 'سطوح دسترسی'],
              currentIndex: c.tab.value,
              index: (value) {
                c.tab.value = value;
                c.load();
              },
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
              onTap: c.loading.value || c.saving.value ? null : c.load,
            ),
          ],
          if (c.pending.value != null) ...[
            Text(
              'درخواست قبلی: ${c.pending.value!.body['displayName'] ?? c.pending.value!.body['name'] ?? 'تغییر دسترسی'}',
            ),
            BTN(
              name: 'ادامه درخواست قبلی',
              disabled: c.loading.value || c.saving.value,
              onTap: () =>
                  c.save(c.pending.value!.resource, c.pending.value!.body),
            ),
          ],
          Expanded(
            child: c.rows.isEmpty
                ? c.loading.value || c.error.value != null
                      ? const SizedBox.shrink()
                      : EmptyList(
                          text: c.tab.value == 0
                              ? 'هیچ میک‌یاری تعریف نکردید.'
                              : 'هیچ سطح‌دسترسی تعریف نکردید.',
                          icon: IconsaxPlusLinear.user_search,
                        )
                : RefreshIndicator(
                    onRefresh: c.load,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 60),
                      itemCount: c.rows.length,
                      itemBuilder: (_, index) {
                        final row = c.rows[index];
                        return InkWell(
                          key: ValueKey(row.id),
                          onTap: () => details(row),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      maxRadius: 25,
                                      backgroundColor: AppColors.boxBackground,
                                      child:
                                          row.resource ==
                                              PersonnelResource.person
                                          ? SvgPicture.asset(SvgIcon.mikyar)
                                          : const Icon(IconsaxPlusLinear.lock),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        row.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      (row.resource == PersonnelResource.person
                                          ? _employment
                                          : _statuses)[row.status]!,
                                    ),
                                    if (row.resource ==
                                            PersonnelResource.person &&
                                        c.canWrite(PersonnelResource.access))
                                      MiniBTN(
                                        key: ValueKey(
                                          'personnel-access-${row.id}',
                                        ),
                                        name: 'سطح دسترسی',
                                        icon: IconsaxPlusLinear.lock,
                                        noFlex: true,
                                        onTap: () => assign(row),
                                      ),
                                  ],
                                ),
                              ),
                              if (index != c.rows.length - 1) EndLine(),
                            ],
                          ),
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

class _PersonnelForm extends StatefulWidget {
  final PersonnelController c;
  final PersonnelResource resource;
  final PersonnelEntry? item;
  const _PersonnelForm({required this.c, required this.resource, this.item});
  @override
  State<_PersonnelForm> createState() => _PersonnelFormState();
}

class _PersonnelFormController extends GetxController {
  _PersonnelFormController(this.widget);
  _PersonnelForm widget;
  late final name = TextEditingController(text: widget.item?.name ?? '');
  final phone = TextEditingController();
  late final code = TextEditingController(
    text: widget.item?.data['personnelCode'] as String? ?? '',
  );
  late final job = TextEditingController(
    text: widget.item?.data['jobTitle'] as String? ?? '',
  );
  late final description = TextEditingController(
    text: widget.item?.data['description'] as String? ?? '',
  );
  final search = TextEditingController();
  late final status = (widget.item?.status ?? 'ACTIVE').obs;
  late final selected = Set<String>.from(
    widget.item?.data['permissionCodes'] as List? ?? [],
  );
  List<Map<String, dynamic>> permissions = [];
  bool ready = false;
}

class _PersonnelFormState extends State<_PersonnelForm> {
  late final _page = _PersonnelFormController(widget);

  bool get person => widget.resource == PersonnelResource.person;
  bool get locked => widget.c.locked;
  @override
  void dispose() {
    for (final field in [
      _page.name,
      _page.phone,
      _page.code,
      _page.job,
      _page.description,
      _page.search,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<Object> load() async {
    // Main starts loading during build; update the surrounding reactive form after that frame.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return '';
    try {
      if (!person) {
        _page.permissions = await widget.c.fx!.catalog();
        if (_page.selected
            .difference(
              _page.permissions.map((p) => p['code'] as String).toSet(),
            )
            .isNotEmpty) {
          throw const FormatException(
            'فهرست مجوزها کامل نیست؛ دوباره تلاش کنید.',
          );
        }
      }
      if (mounted) {
        _page.ready = true;
        _page.update();
      }
    } catch (failure) {
      widget.c.fail(failure);
    }
    return '';
  }

  Future<void> save({bool assign = false}) async {
    if (_page.name.text.trim().isEmpty || _page.name.text.trim().length > 200) {
      Alert.error('نام الزامی و حداکثر ۲۰۰ حرف است.', context: context);
      return;
    }
    final body = <String, dynamic>{};
    if (person) {
      if (_page.code.text.trim().length > 64 ||
          _page.job.text.trim().length > 200) {
        Alert.error('کد پرسنلی یا سمت بیش از حد مجاز است.', context: context);
        return;
      }
      final mobile = _page.phone.text.trim().toEnglishDigit();
      if (widget.item == null && !RegExp(r'^09\d{9}$').hasMatch(mobile)) {
        Alert.error('شماره موبایل ۱۱ رقمی با ۰۹ وارد کنید.', context: context);
        return;
      }
      body.addAll({
        'displayName': _page.name.text.trim(),
        'personnelCode': _page.code.text.trim().isEmpty
            ? null
            : _page.code.text.trim(),
        'jobTitle': _page.job.text.trim().isEmpty
            ? null
            : _page.job.text.trim(),
        'employmentStatus': _page.status.value,
        if (widget.item == null) 'phone': mobile,
      });
    } else {
      if (_page.selected.length > 300 ||
          _page.description.text.trim().length > 1000) {
        Alert.error(
          'حداکثر ۳۰۰ مجوز و ۱۰۰۰ حرف توضیح مجاز است.',
          context: context,
        );
        return;
      }
      body.addAll({
        'name': _page.name.text.trim(),
        'description': _page.description.text.trim().isEmpty
            ? null
            : _page.description.text.trim(),
        'permissionCodes': _page.selected.toList()..sort(),
        'status': _page.status.value,
      });
    }
    final result = await widget.c.save(
      widget.resource,
      body,
      item: widget.item,
    );
    if (mounted && result != null) Get.back(result: (result, assign));
  }

  List<Widget> permissionSections() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final permission in _page.permissions) {
      final group = '${permission['domain']}.${permission['resource']}';
      (groups[group] ??= []).add(permission);
    }
    final query = _page.search.text.trim().toLowerCase();
    return [
      for (final group in groups.entries)
        if (group.value.any((p) => matchesPermission(p, group.key, query)))
          PermissionSection(
            key: ValueKey((group.key, query)),
            sectionName: _permissionGroups[group.key] ?? group.key,
            initiallyExpanded: query.isNotEmpty,
            selectedCount: group.value
                .where((p) => _page.selected.contains(p['code']))
                .length,
            totalCount: group.value.length,
            items: [
              for (final permission in group.value.where(
                (p) => matchesPermission(p, group.key, query),
              ))
                PermissionItem(
                  key: ValueKey('permission-${permission['code']}'),
                  name: permission['title'] as String,
                  initval: _page.selected.contains(permission['code']),
                  enabled: !locked,
                  callback: (value) {
                    final code = permission['code'] as String;
                    if (value) {
                      _page.selected.add(code);
                    } else {
                      _page.selected.remove(code);
                    }
                    _page.update();
                  },
                ),
            ],
          ),
    ];
  }

  bool matchesPermission(
    Map<String, dynamic> permission,
    String group,
    String query,
  ) =>
      '${_permissionGroups[group] ?? group} ${permission['title']} ${permission['code']}'
          .toLowerCase()
          .contains(query);

  @override
  Widget build(BuildContext context) => GetBuilder<_PersonnelFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !widget.c.saving.value,
        child: Main(
          initState: load,
          header: Header.page(
            context,
            text: person
                ? widget.item == null
                      ? 'میک‌یار جدید'
                      : 'ویرایش پرسنل'
                : widget.item == null
                ? 'سطح دسترسی جدید'
                : 'ویرایش سطح دسترسی',
          ),
          child: (_) => Obx(
            () => Column(
              children: [
                if (!_page.ready || widget.c.saving.value)
                  const LinearProgressIndicator(),
                if (widget.c.error.value != null)
                  Text(widget.c.error.value!, textAlign: TextAlign.center),
                if (!_page.ready)
                  MiniBTN(
                    name: 'تلاش مجدد',
                    icon: IconsaxPlusLinear.refresh,
                    noFlex: true,
                    onTap: load,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Input(
                          key: const ValueKey('personnel-name'),
                          controller: _page.name,
                          name: person
                              ? 'نام و نام‌خانوادگی'
                              : 'نام سطح دسترسی',
                          require: true,
                          maxLength: 200,
                          readOnly: locked,
                        ),
                        if (person) ...[
                          if (widget.item == null)
                            Input(
                              key: const ValueKey('personnel-phone'),
                              controller: _page.phone,
                              name: 'شماره موبایل',
                              require: true,
                              maxLength: 11,
                              keyboardType: TextInputType.phone,
                              readOnly: locked,
                            ),
                          Input(
                            controller: _page.code,
                            name: 'کد پرسنلی',
                            maxLength: 64,
                            readOnly: locked,
                          ),
                          Input(
                            controller: _page.job,
                            name: 'سمت',
                            maxLength: 200,
                            readOnly: locked,
                          ),
                        ] else ...[
                          Input(
                            controller: _page.description,
                            name: 'توضیحات',
                            maxLength: 1000,
                            readOnly: locked,
                          ),
                          const Text(
                            'سطح دسترسی، مجموعه‌ای از مجوزهاست؛ مثلاً «فروشنده». مجوزهای موردنیاز را از دسته‌های زیر انتخاب کنید.',
                            textAlign: TextAlign.center,
                          ),
                          Text('${_page.selected.length} مجوز انتخاب شده'),
                          MyDivider(text: 'مجوزها'),
                          Input(
                            controller: _page.search,
                            name: 'جستجوی مجوز',
                            onChanged: (_) {
                              _page.update();
                            },
                            readOnly: locked,
                          ),
                          ...permissionSections(),
                        ],
                        MyDivider(text: person ? 'وضعیت همکاری' : 'وضعیت'),
                        IgnorePointer(
                          ignoring: locked,
                          child: MyTab(
                            tab: (person ? _employment : _statuses).values
                                .toList(),
                            value:
                                ((person
                                        ? _employment
                                        : _statuses)[_page.status.value]!)
                                    .obs,
                            callback: (String value) => _page.status.value =
                                (person ? _employment : _statuses).entries
                                    .singleWhere((e) => e.value == value)
                                    .key,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (person && widget.c.canWrite(PersonnelResource.access))
                  BTN(
                    name: 'ثبت و تعیین سطح دسترسی',
                    disabled: !_page.ready || locked,
                    navigate: true,
                    onTap: () => save(assign: true),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: BTN(
                        name: 'ثبت',
                        disabled: !_page.ready || locked,
                        onTap: save,
                      ),
                    ),
                    Expanded(
                      child: BTN(
                        name: 'انصراف',
                        type: BTNType.cancel,
                        disabled: widget.c.saving.value,
                        onTap: () => Get.back(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant _PersonnelForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

class _PersonnelAccess extends StatefulWidget {
  final PersonnelController c;
  final PersonnelEntry person;
  const _PersonnelAccess({required this.c, required this.person});
  @override
  State<_PersonnelAccess> createState() => _PersonnelAccessState();
}

class _PersonnelAccessController extends GetxController {
  List<PersonnelEntry> roles = [], grants = [];
  List<(String, String)> scopes = [];
  final scope = 'کسب‌وکار'.obs;
  String? scopeId;
  Set<String> selected = {};
  String status = 'ACTIVE';
  bool ready = false, loading = false;
}

class _PersonnelAccessState extends State<_PersonnelAccess> {
  late final _page = _PersonnelAccessController();

  String get scopeType => {
    'کسب‌وکار': 'BUSINESS',
    'شعبه': 'BRANCH',
    'انبار': 'WAREHOUSE',
  }[_page.scope.value]!;
  PersonnelEntry? get grant {
    for (final row in _page.grants) {
      if (row.data['scopeType'] == scopeType &&
          row.data['scopeId'] == _page.scopeId) {
        return row;
      }
    }
    return null;
  }

  void select(String id) {
    {
      _page.scopeId = id;
      _page.selected = Set<String>.from(grant?.data['roleIds'] as List? ?? []);
      _page.status = grant?.status ?? 'ACTIVE';
      _page.update();
    }
  }

  Future<Object> load() async {
    // Main starts loading during build; update the surrounding reactive form after that frame.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return '';
    if (mounted) {
      _page.loading = true;
      _page.update();
    }
    try {
      final fx = widget.c.fx!;
      await fx.authorize();
      _page.roles = await fx.list(PersonnelResource.role);
      _page.grants = await fx.list(
        PersonnelResource.access,
        membershipId: widget.person.data['membershipId'] as String,
      );
      if (!mounted) return '';
      {
        _page.ready = true;
        _page.scopeId ??= '${fx.businessId}';
        _page.update();
      }
      select(_page.scopeId!);
    } catch (failure) {
      widget.c.fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<void> addRole() async {
    final (PersonnelEntry, bool)? result = await Get.toNamed<dynamic>(
      nav_routes.RoutesName.PERSONNEL_FORM,
      arguments: {'c': widget.c, 'resource': PersonnelResource.role},
      preventDuplicates: false,
    );
    if (!mounted || result == null) return;
    {
      _page.roles.removeWhere((role) => role.id == result.$1.id);
      _page.roles.add(result.$1);
      _page.update();
    }
  }

  String get currentAccess {
    final current = grant;
    if (current == null) return 'برای این محدوده سطح دسترسی ثبت نشده است.';
    final ids = (current.data['roleIds'] as List).cast<String>();
    final names = ids
        .map((id) {
          for (final role in _page.roles) {
            if (role.id == id) return role.name;
          }
          return 'سطح دسترسی خارج از فهرست';
        })
        .join('، ');
    return 'دسترسی فعلی: ${names.isEmpty ? 'بدون سطح دسترسی' : names} (${_statuses[current.status]})';
  }

  Future<void> changeScope(String value) async {
    _page.scope.value = value;
    {
      _page.loading = true;
      _page.scopeId = null;
      _page.scopes = [];
      _page.selected = {};
      _page.update();
    }
    try {
      final fx = widget.c.fx!;
      if (scopeType == 'BUSINESS') {
        select('${fx.businessId}');
      } else if (scopeType == 'BRANCH') {
        final rows = await fx.branches();
        if (mounted) {
          {
            _page.scopes = rows.map((r) => (r.branchId, r.name)).toList();
            _page.update();
          }
        }
      } else {
        final rows = await fx.access.warehouses();
        if (mounted) {
          {
            _page.scopes = rows.map((r) => (r.warehouseId, r.name)).toList();
            _page.update();
          }
        }
      }
    } catch (failure) {
      widget.c.fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  String get selectionSummary {
    String location = scopeType == 'BUSINESS'
        ? widget.c.fx!.context.session.business.name
        : _page.scope.value;
    for (final row in _page.scopes) {
      if (row.$1 == _page.scopeId) location = row.$2;
    }
    final names = _page.roles
        .where((role) => _page.selected.contains(role.id))
        .map((role) => role.name)
        .join('، ');
    return '${widget.person.name} • $location\n${names.isEmpty ? 'بدون سطح دسترسی' : names} • ${_statuses[_page.status]}';
  }

  Future<void> save() async {
    if (_page.scopeId == null || _page.selected.length > 30) {
      Alert.error(
        'محدوده و حداکثر ۳۰ سطح دسترسی را انتخاب کنید.',
        context: context,
      );
      return;
    }
    final before = grant;
    if (before == null && _page.selected.isEmpty) {
      Alert.error('حداقل یک سطح دسترسی انتخاب کنید.', context: context);
      return;
    }
    final row = await widget.c.save(PersonnelResource.access, {
      if (before == null) ...{
        'membershipId': widget.person.data['membershipId'],
        'scopeType': scopeType,
        'scopeId': _page.scopeId,
      },
      'roleIds': _page.selected.toList()..sort(),
      'status': _page.status,
    }, item: before);
    if (mounted && row != null) Get.back();
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_PersonnelAccessController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !widget.c.saving.value,
        child: Main(
          initState: load,
          header: Header.page(context, text: 'دسترسی ${widget.person.name}'),
          child: (_) => Obx(
            () => Column(
              children: [
                if (_page.loading || widget.c.saving.value)
                  const LinearProgressIndicator(),
                if (widget.c.error.value != null)
                  Text(widget.c.error.value!, textAlign: TextAlign.center),
                if (!_page.ready)
                  MiniBTN(
                    name: 'تلاش مجدد',
                    icon: IconsaxPlusLinear.refresh,
                    noFlex: true,
                    onTap: _page.loading ? null : load,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        MyDivider(text: '۱. دسترسی کجا اعمال شود؟'),
                        const Text(
                          'برای هر کسب‌وکار، شعبه یا انبار، دسترسی را جداگانه انتخاب و ذخیره کنید.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        IgnorePointer(
                          ignoring:
                              !_page.ready || _page.loading || widget.c.locked,
                          child: MyTab(
                            tab: const ['کسب‌وکار', 'شعبه', 'انبار'],
                            value: _page.scope,
                            callback: changeScope,
                          ),
                        ),
                        if (scopeType == 'BUSINESS')
                          const Text(
                            'این انتخاب برای کارهای سطح کسب‌وکار است؛ برای کارهای هر شعبه یا انبار، همان محدوده را جداگانه تنظیم کنید.',
                            textAlign: TextAlign.center,
                          ),
                        if (scopeType != 'BUSINESS' &&
                            !_page.loading &&
                            _page.scopes.isNotEmpty)
                          Text(
                            scopeType == 'BRANCH'
                                ? 'شعبه موردنظر را انتخاب کنید:'
                                : 'انبار موردنظر را انتخاب کنید:',
                          ),
                        for (final row in _page.scopes)
                          MiniBTN(
                            name: row.$2,
                            icon: _page.scopeId == row.$1
                                ? IconsaxPlusLinear.tick_circle
                                : IconsaxPlusLinear.add_circle,
                            noFlex: true,
                            onTap: _page.loading || widget.c.locked
                                ? null
                                : () => select(row.$1),
                          ),
                        if (scopeType != 'BUSINESS' &&
                            !_page.loading &&
                            _page.scopes.isEmpty)
                          const Text('محدوده قابل انتخابی دریافت نشد.'),
                        MyDivider(text: '۲. چه سطح دسترسی داشته باشد؟'),
                        if (_page.ready &&
                            _page.scopeId != null &&
                            !_page.loading)
                          Text(currentAccess, textAlign: TextAlign.center),
                        if (_page.ready &&
                            widget.c.canWrite(PersonnelResource.role))
                          MiniBTN(
                            name: 'سطح دسترسی جدید',
                            icon: IconsaxPlusLinear.add,
                            noFlex: true,
                            onTap: _page.loading ? null : addRole,
                          ),
                        if (_page.roles.isEmpty && _page.ready)
                          const Text(
                            'هنوز سطح دسترسی‌ای تعریف نشده است. با «سطح دسترسی جدید» مجوزهای موردنیاز را در یک نقش جمع کنید.',
                            textAlign: TextAlign.center,
                          ),
                        if (_page.roles.isNotEmpty)
                          const Text(
                            'می‌توانید چند سطح دسترسی انتخاب کنید؛ مجوزهای نقش‌های فعال با هم اعمال می‌شوند.',
                            textAlign: TextAlign.center,
                          ),
                        for (final role in _page.roles.where(
                          (r) =>
                              r.status == 'ACTIVE' ||
                              _page.selected.contains(r.id),
                        ))
                          MiniBTN(
                            name: role.name,
                            noFlex: true,
                            icon: _page.selected.contains(role.id)
                                ? IconsaxPlusLinear.tick_circle
                                : IconsaxPlusLinear.add_circle,
                            onTap:
                                _page.loading ||
                                    widget.c.locked ||
                                    _page.scopeId == null
                                ? null
                                : () {
                                    if (!_page.selected.remove(role.id)) {
                                      _page.selected.add(role.id);
                                    }
                                    _page.update();
                                  },
                          ),
                        MyDivider(text: '۳. این دسترسی فعال باشد؟'),
                        Text(
                          _page.status == 'ACTIVE'
                              ? 'پس از ذخیره، نقش‌های فعال این محدوده قابل استفاده‌اند.'
                              : 'این تخصیص پس از ذخیره قابل استفاده نیست؛ اطلاعات پرسنل حذف نمی‌شود.',
                          textAlign: TextAlign.center,
                        ),
                        IgnorePointer(
                          ignoring: _page.loading || widget.c.locked,
                          child: MyTab(
                            tab: _statuses.values.toList(),
                            value: _statuses[_page.status]!.obs,
                            callback: (String value) {
                              _page.status = _statuses.entries
                                  .singleWhere((e) => e.value == value)
                                  .key;
                              _page.update();
                            },
                          ),
                        ),
                        if (_page.ready &&
                            _page.scopeId != null &&
                            !_page.loading) ...[
                          MyDivider(text: 'خلاصه انتخاب شما'),
                          Text(selectionSummary, textAlign: TextAlign.center),
                          const Text(
                            'تغییرات با زدن «ثبت دسترسی» ذخیره می‌شوند. پیش از رفتن به محدوده دیگر، انتخاب‌های این محدوده را ثبت کنید.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: BTN(
                        name: 'ثبت دسترسی',
                        disabled:
                            !_page.ready ||
                            _page.loading ||
                            _page.scopeId == null ||
                            widget.c.locked,
                        onTap: save,
                      ),
                    ),
                    Expanded(
                      child: BTN(
                        name: 'انصراف',
                        type: BTNType.cancel,
                        disabled: widget.c.saving.value,
                        onTap: () => Get.back(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget buildPersonnelFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _PersonnelForm(
    c: args.required<PersonnelController>('c'),
    resource: args.required<PersonnelResource>('resource'),
    item: args.optional<PersonnelEntry>('item'),
  );
}

Widget buildPersonnelAccessRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _PersonnelAccess(
    c: args.required<PersonnelController>('c'),
    person: args.required<PersonnelEntry>('person'),
  );
}
