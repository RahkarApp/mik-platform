import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_data/utils/fx/realtime.dart';
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
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/crm.dart';
import 'package:mik_data/source/remote/models/customer.dart';
import 'package:mik_data/source/remote/models/personnel.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/crm.dart';
import 'package:mik_data/utils/fx/personnel.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:uuid/uuid.dart';

const _kinds = {
  'NOTE': 'یادداشت',
  'CALL': 'تماس',
  'VISIT': 'ملاقات',
  'EMAIL': 'ایمیل',
  'OTHER': 'سایر',
};
const _interactionStatus = {'ACTIVE': 'فعال', 'ARCHIVED': 'آرشیو'};
const _followupStatus = {
  'OPEN': 'باز',
  'DONE': 'انجام‌شده',
  'CANCELLED': 'لغوشده',
};

String _date(String value) {
  final date = DateTime.parse(value).toLocal();
  return '${DateConvertor.grigoriToJalali(date.toIso8601String())} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class CustomerCrmScreen extends StatefulWidget {
  final String appId, query;
  final String? customerId;
  final bool embedded, startAdd, showTools;
  const CustomerCrmScreen({
    required this.appId,
    this.customerId,
    this.embedded = false,
    this.startAdd = false,
    this.showTools = false,
    this.query = '',
    super.key,
  });
  @override
  State<CustomerCrmScreen> createState() => _CustomerCrmScreenState();
}

class _CustomerCrmScreenController extends GetxController {
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  bool opening = false;
  String? _selectedCustomerId;
  final customerSearch = TextEditingController();
  final historySearch = TextEditingController();
  String historyQuery = '';
  CrmFX? fx;
  List<RemoteCustomer> customers = [];
  List<CrmEntry> rows = [];
  RemoteCustomer? customer;
  int tab = 0;
  final status = 'فعال'.obs;
  bool loading = false, saving = false;
  String? error;
}

class _CustomerCrmScreenState extends State<CustomerCrmScreen> {
  late final _page = _CustomerCrmScreenController();

  List<CrmEntry> get visibleRows {
    final query = (widget.embedded ? widget.query : _page.historyQuery)
        .trim()
        .toLowerCase()
        .toEnglishDigit();
    return _page.rows
        .where(
          (row) =>
              '${row.title} ${customerName(row.customerId)} ${row.data['note'] ?? ''}'
                  .toLowerCase()
                  .toEnglishDigit()
                  .contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page._readGeneration++;
    _page.customerSearch.dispose();
    _page.historySearch.dispose();
    super.dispose();
  }

  CrmKind get type => _page.tab == 0 ? CrmKind.interaction : CrmKind.followup;
  Map<String, String> get states =>
      _page.tab == 0 ? _interactionStatus : _followupStatus;
  bool get locked => _page.loading || _page.saving || _page.fx?.pending != null;
  bool get canCreate =>
      !locked &&
      _page.customer != null &&
      !_page.customer!.isDefault &&
      _page.customer!.status == 'ACTIVE' &&
      _page.fx?.has('${type.permission}.create') == true;
  @override
  void initState() {
    super.initState();
    final active = BusinessContext.forApp(widget.appId);
    if (active != null) {
      _page._realtime = RealtimeWatch(
        RealtimeFX.forContext(active),
        {
          'ucrm.customer',
          'ucrm.interaction',
          'ucrm.followup',
          'ucrm.group',
          'ucrm.tag',
        },
        () => load(background: true),
        busy: () => _page.loading || _page.saving || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page._readGeneration++;
              _page.loading = false;
              _page.rows = [];
              _page.customers = [];
              _page._selectedCustomerId =
                  _page.customer?.id ?? _page._selectedCustomerId;
              _page.customer = null;
              _page.update();
            }
          }
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => load(first: true));
  }

  void fail(Object failure) {
    if (!mounted) return;
    final message = CrmFX.message(failure);
    {
      _page.error = message;
      if (failure is AuthError &&
          (failure.statusCode == 403 ||
              failure.requiresLogin ||
              failure.code == 'SELECTION_CHANGED')) {
        _page.rows = [];
        _page.customers = [];
        _page.customer = null;
      }
      _page.update();
    }
    Alert.error(message, context: context);
  }

  Future<void> load({bool first = false, bool background = false}) async {
    if (!mounted || _page.loading || _page.saving) return;
    final request = ++_page._readGeneration;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.rows = [];
      _page.update();
    }
    try {
      final context = BusinessContext.forApp(widget.appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= CrmFX.forContext(context);
      await _page.fx!.authorize();
      await _page.fx!.restore();
      final list = _page.fx!.customers.canRead
          ? await _page.fx!.customerList()
          : <RemoteCustomer>[];
      if (!mounted || request != _page._readGeneration) return;
      _page.customers = list;
      final id =
          _page.customer?.id ??
          _page._selectedCustomerId ??
          (first ? widget.customerId : null);
      _page._selectedCustomerId = id;
      _page.customer = null;
      for (final row in _page.customers) {
        if (row.id == id) _page.customer = row;
      }
      if (id != null && !Uuid.isValidUUID(fromString: id)) {
        Alert.error(
          'شناسه مشتری قدیمی قابل استفاده نیست؛ مشتری را از فهرست جدید انتخاب کنید.',
          context: this.context,
        );
      }
      await fetchRows(generation: request);
    } catch (failure) {
      if (request == _page._readGeneration) fail(failure);
    } finally {
      if (mounted && request == _page._readGeneration) {
        {
          _page.loading = false;
          _page.update();
        }
      }
    }
    if (first &&
        widget.startAdd &&
        mounted &&
        request == _page._readGeneration &&
        _page.fx != null &&
        _page.error == null) {
      await add();
    }
  }

  Future<void> fetchRows({int? generation}) async {
    final request = generation ?? _page._readGeneration;
    if (type == CrmKind.interaction && _page.customer == null) {
      _page.rows = [];
      return;
    }
    final code = states.entries
        .singleWhere((e) => e.value == _page.status.value)
        .key;
    final result = await _page.fx!.list(
      type,
      customerId: _page.customer?.id,
      status: code,
    );
    // UUID pagination is stable; sort the fully loaded history by its actual date.
    final field = type == CrmKind.interaction ? 'occurredAt' : 'dueAt';
    result.sort(
      (a, b) => type == CrmKind.interaction
          ? DateTime.parse(b.data[field] as String)
                .compareTo(DateTime.parse(a.data[field] as String))
          : DateTime.parse(a.data[field] as String)
                .compareTo(DateTime.parse(b.data[field] as String)),
    );
    if (mounted && request == _page._readGeneration) {
      _page.rows = result;
      _page.update();
    }
  }

  Future<void> refresh() async {
    if (_page.loading || _page.saving) return;
    final request = ++_page._readGeneration;
    {
      _page.loading = true;
      _page.error = null;
      _page.rows = [];
      _page.update();
    }
    try {
      await _page.fx!.authorize();
      await fetchRows(generation: request);
    } catch (failure) {
      if (request == _page._readGeneration) fail(failure);
    } finally {
      if (mounted && request == _page._readGeneration) {
        {
          _page.loading = false;
          _page.update();
        }
      }
    }
  }

  Future<void> chooseCustomer() async {
    if (locked || _page.fx == null) return;
    if (_page.customers.isEmpty) {
      Alert.error(
        'مشتری قابل انتخابی دریافت نشده؛ فهرست مشتریان و مجوز مشاهده آن را بررسی کنید.',
        context: context,
      );
      return;
    }
    _page.customerSearch.clear();
    final result = await MyBottomSheet.view(
      context,
      title: 'انتخاب مشتری',
      child: (_) => GetBuilder<_CrmCustomerSearchController>(
        init: _CrmCustomerSearchController(),
        global: false,
        dispose: (state) => state.controller?.onDelete(),
        builder: (sheet) => Column(
          children: [
            Input(
              controller: _page.customerSearch,
              name: 'جستجوی مشتری',
              onChanged: (value) {
                sheet.query = value.toString().trim().toEnglishDigit();
                sheet.update();
              },
            ),
            for (final row in _page.customers.where(
              (c) => '${c.name} ${c.phone ?? ''}'.toEnglishDigit().contains(
                sheet.query,
              ),
            ))
              MiniBTN(
                name:
                    '${row.name}${row.status == 'ARCHIVED' ? ' (آرشیو)' : ''}',
                noFlex: true,
                icon: IconsaxPlusLinear.user,
                onTap: () => Get.back(result: row),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result is! RemoteCustomer) return;
    {
      _page.customer = result;
      _page._selectedCustomerId = result.id;
      _page.update();
    }
    await refresh();
  }

  Future<void> add() async {
    if (_page.customer == null) await chooseCustomer();
    if (!mounted) return;
    if (!canCreate) {
      Alert.error(
        'مشتری فعال را انتخاب کنید و مجوز ثبت را بررسی کنید؛ مشتری متفرقه قابل استفاده نیست.',
        context: context,
      );
      return;
    }
    _page.opening = true;
    try {
      await Get.toNamed(
        nav_routes.RoutesName.CRM_FORM,
        arguments: {'fx': _page.fx!, 'customer': _page.customer!, 'type': type},
        preventDuplicates: false,
      );
    } finally {
      _page.opening = false;
    }
    if (mounted) await refresh();
  }

  Future<void> resume() async {
    final command = _page.fx?.pending;
    if (command == null || _page.loading || _page.saving) return;
    {
      _page.saving = true;
      _page.update();
    }
    try {
      await _page.fx!.send(command);
      if (mounted) Alert.success('درخواست قبلی با موفقیت ثبت شد.');
    } catch (failure) {
      fail(failure);
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
    if (mounted) await refresh();
  }

  String customerName(String id) {
    for (final row in _page.customers) {
      if (row.id == id) return row.name;
    }
    return 'نام مشتری در دسترس نیست';
  }

  Future<void> details(CrmEntry entry) async {
    if (locked) return;
    try {
      await _page.fx!.authorize();
      final row = await _page.fx!.get(entry);
      if (!mounted) return;
      RemoteCustomer? parent;
      for (final customer in _page.customers) {
        if (customer.id == row.customerId) parent = customer;
      }
      await MyBottomSheet.view(
        context,
        title: customerName(row.customerId),
        child: (_) => Column(
          children: [
            Text(row.title),
            MyDivider(),
            if (row.type == CrmKind.interaction)
              Text('نوع ارتباط: ${_kinds[row.data['kind']]}'),
            if (row.type == CrmKind.followup && row.data['note'] != null)
              Text(row.data['note'] as String),
            Text(
              _date(
                row.data[row.type == CrmKind.interaction
                        ? 'occurredAt'
                        : 'dueAt']
                    as String,
              ),
            ),
            Text(
              'وضعیت: ${(row.type == CrmKind.interaction ? _interactionStatus : _followupStatus)[row.status]}',
            ),
            if (row.data['overdue'] == true)
              const Text('موعد این پیگیری گذشته است.'),
            if (row.type == CrmKind.followup && row.data['completedAt'] != null)
              Text('تاریخ انجام: ${_date(row.data['completedAt'] as String)}'),
            if (row.data['changeReason'] != null)
              Text('دلیل آخرین تغییر: ${row.data['changeReason']}'),
            if (parent != null && !parent.isDefault && _page.fx!.canEdit(row))
              MiniBTN(
                name: 'ویرایش',
                icon: IconsaxPlusLinear.edit_2,
                noFlex: true,
                onTap: () async {
                  Get.back();
                  _page.opening = true;
                  try {
                    await Get.toNamed(
                      nav_routes.RoutesName.CRM_FORM,
                      arguments: {
                        'fx': _page.fx!,
                        'customer': parent!,
                        'type': row.type,
                        'item': row,
                      },
                      preventDuplicates: false,
                    );
                  } finally {
                    _page.opening = false;
                  }
                  if (mounted) await refresh();
                },
              ),
            BTN(name: 'بستن', onTap: () => Get.back()),
          ],
        ),
      );
    } catch (failure) {
      fail(failure);
    }
  }

  Widget body() => Column(
    children: [
      IgnorePointer(
        ignoring: _page.loading || _page.saving,
        child: MyTabBar(
          tabs: const ['ارتباطات', 'پیگیری‌ها'],
          currentIndex: _page.tab,
          index: (value) {
            {
              _page.tab = value;
              _page.status.value = _page.tab == 0 ? 'فعال' : 'باز';
              _page.update();
            }
            refresh();
          },
        ),
      ),
      if (!widget.embedded)
        MySearchBar(
          controller: _page.historySearch,
          type: SearchBarType.user,
          enableScanner: false,
          hintText: 'جستجو در ارتباطات و پیگیری‌ها',
          callback: (value) {
            _page.historyQuery = value.toString();
            _page.update();
          },
        ),
      Row(
        children: [
          Expanded(
            child: MiniBTN(
              name: _page.customer?.name ?? 'انتخاب مشتری',
              noFlex: true,
              icon: IconsaxPlusLinear.user,
              onTap: locked ? null : chooseCustomer,
            ),
          ),
          if (_page.tab == 1 && _page.customer != null)
            MiniBTN(
              name: 'همه مشتریان',
              noFlex: true,
              icon: IconsaxPlusLinear.people,
              onTap: locked
                  ? null
                  : () {
                      {
                        _page.customer = null;
                        _page.update();
                      }
                      refresh();
                    },
            ),
        ],
      ),
      IgnorePointer(
        ignoring: _page.loading || _page.saving,
        child: MyTab(
          tab: states.values.toList(),
          value: _page.status,
          callback: (String value) {
            _page.status.value = value;
            refresh();
          },
        ),
      ),
      if (_page.loading || _page.saving) const LinearProgressIndicator(),
      if (_page.error != null) ...[
        Text(_page.error!, textAlign: TextAlign.center),
        MiniBTN(
          name: 'تلاش مجدد',
          noFlex: true,
          icon: IconsaxPlusLinear.refresh,
          onTap: _page.loading || _page.saving ? null : load,
        ),
      ],
      if (_page.fx?.pending != null)
        BTN(
          name: 'ادامه درخواست قبلی',
          disabled: _page.loading || _page.saving,
          onTap: resume,
        ),
      if (_page.tab == 0 && _page.customer == null)
        const Text('برای مشاهده تاریخچه ارتباطات، مشتری را انتخاب کنید.'),
      Expanded(
        child: visibleRows.isEmpty
            ? _page.loading || _page.error != null
                  ? const SizedBox.shrink()
                  : EmptyList(
                      text:
                          _page.historyQuery.isNotEmpty ||
                              widget.query.isNotEmpty
                          ? 'موردی با این مشخصات پیدا نشد.'
                          : 'موردی برای نمایش وجود ندارد.',
                      icon: IconsaxPlusLinear.call_slash,
                    )
            : RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  children: [
                    for (final row in visibleRows)
                      InkWell(
                        key: ValueKey(row.id),
                        onTap: () => details(row),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    maxRadius: 25,
                                    backgroundColor: AppColors.boxBackground,
                                    child: Icon(
                                      row.type == CrmKind.interaction
                                          ? IconsaxPlusLinear.call_calling
                                          : IconsaxPlusLinear.calendar,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customerName(row.customerId),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          row.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _date(
                                            row.data[row.type ==
                                                        CrmKind.interaction
                                                    ? 'occurredAt'
                                                    : 'dueAt']
                                                as String,
                                          ),
                                        ),
                                        if (row.data['overdue'] == true)
                                          const Text('موعد گذشته'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            EndLine(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    return GetBuilder<_CustomerCrmScreenController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final fab =
            _page.fx != null && _page.fx!.has('${type.permission}.create')
            ? MyFAB(
                icon: IconsaxPlusLinear.add,
                text: _page.tab == 0 ? 'ارتباط جدید' : 'پیگیری جدید',
                onTap: add,
              )
            : null;
        if (widget.embedded) {
          return Scaffold(
            floatingActionButtonLocation:
                FloatingActionButtonLocation.startDocked,
            floatingActionButton: fab,
            body: body(),
          );
        }
        return Main(
          initState: () async => '',
          header: Header.page(context, text: 'ارتباط با مشتریان'),
          footer: widget.showTools
              ? Row(
                  children: [
                    MiniBTN(
                      name: 'جدید',
                      color: AppColors.secondary,
                      icon: IconsaxPlusLinear.add,
                      onTap: add,
                    ),
                    MiniBTN(
                      name: 'ارتباطات',
                      color: AppColors.secondary,
                      icon: IconsaxPlusLinear.call_calling,
                      onTap: _page.loading || _page.saving
                          ? null
                          : () {
                              {
                                _page.tab = 0;
                                _page.status.value = 'فعال';
                                _page.update();
                              }
                              refresh();
                            },
                    ),
                    MiniBTN(
                      name: 'کدتخفیف',
                      color: AppColors.blue,
                      icon: IconsaxPlusLinear.discount_shape,
                      onTap: () => Alert.warning(
                        'کد تخفیف هنوز به API جدید متصل نشده است.',
                      ),
                    ),
                    MiniBTN(
                      name: 'کمپین‌ها',
                      color: AppColors.yellow,
                      icon: IconsaxPlusLinear.notification,
                      onTap: () => Alert.warning(
                        'کمپین‌ها هنوز به API جدید متصل نشده‌اند.',
                      ),
                    ),
                    MiniBTN(
                      name: 'گزارشات',
                      color: AppColors.primary,
                      icon: IconsaxPlusLinear.chart_3,
                      onTap: () => Alert.warning(
                        'گزارشات CRM هنوز به API جدید متصل نشده‌اند.',
                      ),
                    ),
                  ],
                )
              : null,
          floatingActionButton: fab,
          child: (_) => body(),
        );
      },
    );
  }
}

class _CrmForm extends StatefulWidget {
  final CrmFX fx;
  final RemoteCustomer customer;
  final CrmKind type;
  final CrmEntry? item;
  const _CrmForm({
    required this.fx,
    required this.customer,
    required this.type,
    this.item,
  });
  @override
  State<_CrmForm> createState() => _CrmFormState();
}

class _CrmFormController extends GetxController {
  _CrmFormController(this.widget);
  _CrmForm widget;
  late final body = TextEditingController(
    text: widget.item?.data[interaction ? 'body' : 'note'] as String? ?? '',
  );
  late final title = TextEditingController(
    text: widget.item?.data['title'] as String? ?? '',
  );
  late final initialDate = widget.item == null
      ? interaction
            ? DateConvertor.jalaliTimeNow()
            : ''
      : _date(widget.item!.data[interaction ? 'occurredAt' : 'dueAt'] as String)
            .toEnglishDigit();
  late final date = TextEditingController(text: initialDate);
  final reason = TextEditingController();
  late final kind = (_kinds[widget.item?.data['kind']] ?? 'تماس').obs;
  late final status =
      ((interaction
              ? _interactionStatus
              : _followupStatus)[widget.item?.status ??
              (interaction ? 'ACTIVE' : 'OPEN')]!)
          .obs;
  String? responsible;
  String? responsibleName;
  bool saving = false;
  bool get interaction => widget.type == CrmKind.interaction;
}

class _CrmFormState extends State<_CrmForm> {
  late final _page = _CrmFormController(widget);

  @override
  void dispose() {
    for (final field in [_page.body, _page.title, _page.date, _page.reason]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> chooseResponsible() async {
    try {
      final people = PersonnelFX.forContext(widget.fx.context);
      await people.authorize();
      final rows = await people.list(PersonnelResource.person);
      if (!mounted) return;
      await MyBottomSheet.view(
        context,
        title: 'مسئول پیگیری',
        child: (_) => Column(
          children: [
            MiniBTN(
              name: 'خودم',
              noFlex: true,
              icon: IconsaxPlusLinear.user,
              onTap: () {
                {
                  _page.responsible =
                      widget.fx.context.session.business.membershipId;
                  _page.responsibleName = 'خودم';
                  _page.update();
                }
                Get.back();
              },
            ),
            for (final row in rows.where(
              (r) =>
                  r.status == 'ACTIVE' &&
                  widget.customer.assignedMembershipIds.contains(
                    r.data['membershipId'],
                  ),
            ))
              MiniBTN(
                name: row.name,
                noFlex: true,
                icon: IconsaxPlusLinear.user,
                onTap: () {
                  {
                    _page.responsible = row.data['membershipId'] as String;
                    _page.responsibleName = row.name;
                    _page.update();
                  }
                  Get.back();
                },
              ),
            const Text(
              'فقط پرسنلی قابل انتخاب‌اند که این مشتری قبلاً به آن‌ها واگذار شده باشد.',
            ),
          ],
        ),
      );
    } catch (failure) {
      if (mounted) Alert.error(CrmFX.message(failure), context: context);
    }
  }

  Future<void> save() async {
    if (_page.saving || widget.fx.pending != null) return;
    final text = _page.body.text.trim(),
        caption = _page.title.text.trim(),
        why = _page.reason.text.trim();
    if ((_page.interaction && text.isEmpty) ||
        text.length > 5000 ||
        !_page.interaction && (caption.isEmpty || caption.length > 200) ||
        widget.item != null && (why.isEmpty || why.length > 1000) ||
        _page.date.text.trim().isEmpty) {
      Alert.error(
        'توضیحات ارتباط یا عنوان پیگیری، تاریخ و دلیل ویرایش را کامل کنید.',
        context: context,
      );
      return;
    }
    String timestamp;
    try {
      timestamp = widget.item != null && _page.date.text == _page.initialDate
          ? widget.item!.data[_page.interaction ? 'occurredAt' : 'dueAt']
                as String
          : DateTime.parse(
              DateConvertor.jalaliToGrigori(_page.date.text.toEnglishDigit()),
            ).toUtc().toIso8601String();
      if (_page.interaction &&
          DateTime.parse(timestamp).isAfter(DateTime.now())) {
        throw const FormatException('future');
      }
    } catch (_) {
      Alert.error(
        'تاریخ معتبر وارد کنید؛ زمان ارتباط نباید در آینده باشد.',
        context: context,
      );
      return;
    }
    final data = <String, dynamic>{
      if (widget.item == null) 'customerId': widget.customer.id,
      if (_page.interaction) ...{
        'body': text,
        'occurredAt': timestamp,
        if (widget.item == null)
          'kind': _kinds.entries
              .singleWhere((e) => e.value == _page.kind.value)
              .key,
      },
      if (!_page.interaction) ...{
        'title': caption,
        'note': text.isEmpty ? null : text,
        'dueAt': timestamp,
        if (_page.responsible != null &&
            _page.responsible != widget.item?.data['responsibleMembershipId'])
          'responsibleMembershipId': _page.responsible,
      },
      if (widget.item != null) ...{
        'reason': why,
        'expectedRevision': widget.item!.revision,
        'status': (_page.interaction ? _interactionStatus : _followupStatus)
            .entries
            .singleWhere((e) => e.value == _page.status.value)
            .key,
      },
    };
    {
      _page.saving = true;
      _page.update();
    }
    try {
      await widget.fx.send(
        CrmCommand(widget.type, widget.customer.id, data, id: widget.item?.id),
      );
      if (mounted) {
        Alert.success('اطلاعات با موفقیت ثبت شد.');
        Get.back();
      }
    } catch (failure) {
      if (mounted) Alert.error(CrmFX.message(failure), context: context);
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_CrmFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: _page.interaction
              ? 'ارتباط با ${widget.customer.name}'
              : 'پیگیری ${widget.customer.name}',
        ),
        child: (_) => Column(
          children: [
            if (_page.saving) const LinearProgressIndicator(),
            if (widget.fx.pending != null)
              const Text(
                'نتیجه درخواست مشخص نیست؛ فرم را ببندید و «ادامه درخواست قبلی» را بزنید.',
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_page.interaction && widget.item == null)
                      IgnorePointer(
                        ignoring: _page.saving || widget.fx.pending != null,
                        child: MyTab(
                          tab: _kinds.values.toList(),
                          value: _page.kind,
                          callback: (String value) => _page.kind.value = value,
                        ),
                      ),
                    if (!_page.interaction)
                      Input(
                        key: const ValueKey('crm-title'),
                        controller: _page.title,
                        name: 'عنوان پیگیری',
                        maxLength: 200,
                        require: true,
                        readOnly: _page.saving || widget.fx.pending != null,
                      ),
                    Input(
                      key: const ValueKey('crm-body'),
                      controller: _page.body,
                      name: 'توضیحات',
                      require: _page.interaction,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 5000,
                      readOnly: _page.saving || widget.fx.pending != null,
                    ),
                    IgnorePointer(
                      ignoring: _page.saving || widget.fx.pending != null,
                      child: DateInput(
                        controller: _page.date,
                        name: _page.interaction
                            ? 'تاریخ ارتباط'
                            : 'زمان پیگیری',
                        require: true,
                        timePicker: true,
                        onChanged: (_) {},
                      ),
                    ),
                    if (!_page.interaction) ...[
                      Text(
                        'مسئول پیگیری: ${_page.responsibleName ?? (widget.item == null || widget.item!.data['responsibleMembershipId'] == widget.fx.context.session.business.membershipId ? 'خودم' : 'مسئول فعلی')}',
                      ),
                      if (widget.fx.has('ucrm.followup.assign') &&
                          widget.fx.has('business.personnel.read'))
                        MiniBTN(
                          name: 'انتخاب مسئول',
                          noFlex: true,
                          icon: IconsaxPlusLinear.user,
                          onTap: _page.saving || widget.fx.pending != null
                              ? null
                              : chooseResponsible,
                        ),
                    ],
                    if (widget.item != null) ...[
                      MyDivider(text: 'وضعیت'),
                      IgnorePointer(
                        ignoring: _page.saving || widget.fx.pending != null,
                        child: MyTab(
                          tab:
                              (_page.interaction
                                      ? _interactionStatus
                                      : _followupStatus)
                                  .values
                                  .toList(),
                          value: _page.status,
                          callback: (String value) =>
                              _page.status.value = value,
                        ),
                      ),
                      if (!_page.interaction && widget.item!.status != 'OPEN')
                        const Text(
                          'برای تغییر نتیجه پیگیری بسته‌شده، ابتدا وضعیت «باز» را ذخیره کنید.',
                        ),
                      Input(
                        key: const ValueKey('crm-reason'),
                        controller: _page.reason,
                        name: 'دلیل ویرایش',
                        maxLength: 1000,
                        require: true,
                        readOnly: _page.saving || widget.fx.pending != null,
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
                    name: 'ثبت',
                    disabled: _page.saving || widget.fx.pending != null,
                    onTap: save,
                  ),
                ),
                Expanded(
                  child: BTN(
                    name: 'انصراف',
                    type: BTNType.cancel,
                    disabled: _page.saving,
                    onTap: () => Get.back(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant _CrmForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

class _CrmCustomerSearchController extends GetxController {
  String query = '';
}

Widget buildCustomerCrmRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return CustomerCrmScreen(
    appId: args.required<String>('appId'),
    customerId: args.optional<String>('customerId'),
    embedded: args.optional<bool>('embedded') ?? false,
    startAdd: args.optional<bool>('startAdd') ?? false,
    showTools: args.optional<bool>('showTools') ?? false,
    query: args.optional<String>('query') ?? '',
  );
}

Widget buildCrmFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _CrmForm(
    fx: args.required<CrmFX>('fx'),
    customer: args.required<RemoteCustomer>('customer'),
    type: args.required<CrmKind>('type'),
    item: args.optional<CrmEntry>('item'),
  );
}
