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
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:uuid/uuid.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_consts/svgIcon.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'server_controller.dart';

class SuppliersScreen extends StatefulWidget {
  final String appId;
  final AccountingPersonType type;
  const SuppliersScreen({
    required this.appId,
    this.type = AccountingPersonType.supplier,
    super.key,
  });
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final c = SuppliersController(
    appId: widget.appId,
    type: widget.type,
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

  Future<void> add() async {
    if (c.saving.value) {
      Alert.warning('ثبت قبلی در حال انجام است.');
      return;
    }
    c.commandError.value = null;
    await Get.toNamed(
      nav_routes.RoutesName.SUPPLIER_FORM,
      arguments: {'c': c},
      preventDuplicates: false,
    );
  }

  Future<void> details(RemoteSupplier row) async {
    final item = await c.details(row);
    if (!mounted || item == null) return;
    await MyBottomSheet.view(
      context,
      title: item.name,
      child: (_) => Column(
        children: [
          SelectableText('شناسه: ${item.id}'),
          MyDivider(),
          Text('شماره موبایل: ${item.phone ?? 'ثبت نشده'}'),
          Text(
            'نوع: ${item.kind == 'PERSON'
                ? 'حقیقی'
                : item.kind == 'ORGANIZATION'
                ? 'حقوقی'
                : 'ثبت نشده'}',
          ),
          for (final field in _SupplierFormState.labels.entries)
            if (item.profile[field.key] != null)
              Text('${field.value}: ${item.profile[field.key]}'),
          for (final address in (item.profile['addresses'] as List? ?? [])) ...[
            MyDivider(),
            Text(
              '${address['title']}${address['isDefault'] == true ? ' (پیش‌فرض)' : ''}',
            ),
            for (final field in _SupplierAddress.labels.entries)
              if (address[field.key] != null && field.key != 'title')
                Text('${field.value}: ${address[field.key]}'),
          ],
          Text('وضعیت: ${item.status == 'ACTIVE' ? 'فعال' : 'آرشیو'}'),
          MyDivider(),
          if (widget.type == AccountingPersonType.partner) ...[
            Text(
              'مانده سرمایه: ${item.capitalBalance?.toString().toPersianDigit() ?? 'نامشخص'}',
            ),
            Text(
              'مانده جاری: ${item.currentBalance?.toString().toPersianDigit() ?? 'نامشخص'}',
            ),
          ] else
            Text(
              widget.type == AccountingPersonType.supplier
                  ? 'مجموع خرید: نامشخص'
                  : 'مجموع هزینه: نامشخص',
            ),
          if (widget.type != AccountingPersonType.partner)
            const Text('مانده حساب: نامشخص'),
          if (widget.type == AccountingPersonType.supplier &&
              item.status == 'ACTIVE')
            MiniBTN(
              name: 'صورت‌حساب و گردش حساب',
              icon: IconsaxPlusLinear.document_text,
              noFlex: true,
              onTap: () {
                Get.back();
                Get.toNamed(
                  nav_routes.RoutesName.PARTY_ACCOUNT,
                  arguments: {
                    'appId': widget.appId,
                    'partyType': 'SUPPLIER',
                    'partyId': item.id,
                  },
                  preventDuplicates: false,
                );
              },
            ),
          if (widget.type == AccountingPersonType.partner)
            MiniBTN(
              name: 'آورده، برداشت و گردش حساب',
              icon: IconsaxPlusLinear.document_text,
              noFlex: true,
              onTap: () async {
                Get.back();
                await Get.toNamed(
                  nav_routes.RoutesName.PARTNER_MOVEMENTS,
                  arguments: {'appId': widget.appId, 'partnerId': item.id},
                  preventDuplicates: false,
                );
                if (mounted) await c.load();
              },
            ),
          if (c.canEdit(item))
            MiniBTN(
              name: 'ویرایش',
              icon: IconsaxPlusLinear.edit_2,
              noFlex: true,
              onTap: () async {
                Get.back();
                c.commandError.value = null;
                await Get.toNamed(
                  nav_routes.RoutesName.SUPPLIER_FORM,
                  arguments: {'c': c, 'item': item},
                  preventDuplicates: false,
                );
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
    header: Header.page(context, text: widget.type.plural, isBack: false),
    floatingActionButton: Obx(
      () => c.canCreate
          ? MyFAB(
              icon: IconsaxPlusLinear.add,
              text: '${widget.type.singular} جدید',
              onTap: add,
            )
          : const SizedBox.shrink(),
    ),
    child: (_) => Column(
      children: [
        const SizedBox(height: 10),
        Obx(
          () => IgnorePointer(
            ignoring: c.loading.value || c.saving.value,
            child: MyTab(
              tab: const ['فعال', 'آرشیو'],
              value: c.status,
              callback: (String value) {
                c.status.value = value;
                c.load();
              },
            ),
          ),
        ),
        if (widget.type == AccountingPersonType.partner)
          Obx(
            () => c.loading.value || c.error.value != null
                ? const SizedBox.shrink()
                : MiniBTN(
                    name: 'سهم و مالکیت شرکا',
                    icon: IconsaxPlusLinear.percentage_circle,
                    noFlex: true,
                    onTap: c.saving.value
                        ? null
                        : () async {
                            await Get.toNamed(
                              nav_routes.RoutesName.PARTNER_OWNERSHIP,
                              arguments: {'appId': widget.appId},
                              preventDuplicates: false,
                            );
                          },
                  ),
          ),
        MySearchBar(
          type: SearchBarType.user,
          controller: search,
          enableScanner: false,
          hintText:
              'برای جستجو نام یا شماره موبایل ${widget.type.singular} را وارد کنید...',
          callback: c.search,
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
                if (c.pending.value != null) ...[
                  Text('درخواست قبلی: ${c.pending.value!.body['name']}'),
                  BTN(
                    name: 'ادامه درخواست قبلی',
                    disabled: c.saving.value,
                    navigate: true,
                    onTap: add,
                  ),
                ],
                Expanded(
                  child: c.visible.isEmpty
                      ? c.loading.value || c.error.value != null
                            ? const SizedBox.shrink()
                            : EmptyList(
                                text: c.query.value.isEmpty
                                    ? 'هیچ فردی تعریف نشده است.'
                                    : '${widget.type.singular}‌ای با این مشخصات موجود نیست!',
                                icon: IconsaxPlusLinear.user_search,
                              )
                      : RefreshIndicator(
                          onRefresh: c.load,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 60),
                            itemCount: c.visible.length,
                            itemBuilder: (context, index) {
                              final row = c.visible[index];
                              return InkWell(
                                key: ValueKey(row.id),
                                onTap: () => details(row),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.only(
                                        top: 5,
                                        bottom: 5,
                                        right: 20,
                                        left: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                AppColors.boxBackground,
                                            maxRadius: 25,
                                            child: SvgPicture.asset(
                                              widget.type ==
                                                      AccountingPersonType
                                                          .supplier
                                                  ? SvgIcon.supplier
                                                  : widget.type ==
                                                        AccountingPersonType
                                                            .partner
                                                  ? SvgIcon.partner
                                                  : SvgIcon.servicer,
                                              height: 40,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
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
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      row.phone ??
                                                          'موبایل ثبت نشده',
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    widget.type ==
                                                            AccountingPersonType
                                                                .partner
                                                        ? 'مانده سرمایه: ${row.capitalBalance?.toString().toPersianDigit() ?? 'نامشخص'}'
                                                        : 'وضعیت مالی: نامشخص',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (index != c.visible.length - 1)
                                      EndLine(),
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
        ),
      ],
    ),
  );
}

class SupplierFormScreen extends StatefulWidget {
  final SuppliersController c;
  final RemoteSupplier? item;
  const SupplierFormScreen({super.key, required this.c, this.item});
  @override
  State<SupplierFormScreen> createState() => _SupplierFormState();
}

class _SupplierFormController extends GetxController {
  _SupplierFormController(this.widget);
  SupplierFormScreen widget;
  late final initial =
      widget.c.pending.value?.body ??
      widget.item?.profile ??
      <String, dynamic>{};
  late final name = TextEditingController(
    text: initial['name'] as String? ?? '',
  );
  late final phone = TextEditingController(
    text: initial['phone'] as String? ?? '',
  );
  late final fields = {
    for (final key in _SupplierFormState.labels.keys.where(
      widget.c.type.profileFields.contains,
    ))
      key: TextEditingController(text: initial[key] as String? ?? ''),
  };
  late final kind =
      (initial['kind'] == 'PERSON'
              ? 'حقیقی'
              : initial['kind'] == 'ORGANIZATION'
              ? 'حقوقی'
              : widget.item == null && widget.c.pending.value == null
              ? 'حقیقی'
              : '')
          .obs;
  late final status =
      ((initial['status'] ?? widget.item?.status) == 'ARCHIVED'
              ? 'آرشیو'
              : 'فعال')
          .obs;
  late final addresses = [
    for (final row in (initial['addresses'] as List? ?? []))
      _SupplierAddress(Map<String, dynamic>.from(row as Map)),
  ];
  final removedAddresses = <_SupplierAddress>[];
}

class _SupplierFormState extends State<SupplierFormScreen> {
  late final _page = _SupplierFormController(widget);

  static const labels = {
    'reference': 'کد مرجع',
    'note': 'یادداشت',
    'legalName': 'نام قانونی شرکت',
    'email': 'ایمیل',
    'telephone': 'تلفن ثابت',
    'nationalId': 'کد / شناسه ملی',
    'registrationNumber': 'شماره ثبت',
    'economicCode': 'کد اقتصادی',
  };
  static const limits = {
    'reference': 100,
    'note': 1000,
    'legalName': 200,
    'email': 254,
    'telephone': 32,
    'nationalId': 11,
    'registrationNumber': 64,
    'economicCode': 32,
  };

  bool get locked => widget.c.saving.value || widget.c.pending.value != null;
  bool get updating =>
      widget.item != null || widget.c.pending.value?.updating == true;
  @override
  void dispose() {
    _page.name.dispose();
    _page.phone.dispose();
    for (final field in _page.fields.values) {
      field.dispose();
    }
    for (final address in [..._page.addresses, ..._page.removedAddresses]) {
      address.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool another = false}) async {
    final details = <String, dynamic>{
      for (final field in _page.fields.entries) field.key: field.value.text,
    };
    // Address IDs stay stable while editing and on retry; existing optional fields are preserved.
    try {
      if (widget.c.type != AccountingPersonType.partner) {
        details['addresses'] = _page.addresses
            .map((row) => row.body())
            .toList();
      }
    } on FormatException catch (failure) {
      Alert.error(failure.message, context: context);
      return;
    }
    final result = await widget.c.create(
      _page.name.text,
      _page.phone.text,
      kind: _page.kind.value == 'حقیقی'
          ? 'PERSON'
          : _page.kind.value == 'حقوقی'
          ? 'ORGANIZATION'
          : null,
      details: details,
      item: widget.item,
      status: _page.status.value == 'آرشیو' ? 'ARCHIVED' : 'ACTIVE',
    );
    if (!mounted || result == null) return;
    if (another) {
      {
        _page.name.clear();
        _page.phone.clear();
        _page.kind.value = 'حقیقی';
        _page.status.value = 'فعال';
        for (final field in _page.fields.values) {
          field.clear();
        }
        _page.removedAddresses.addAll(_page.addresses);
        _page.addresses.clear();
        _page.update();
      }
    } else {
      Get.back();
    }
  }

  Widget input(
    String key,
    String label,
    TextEditingController controller, {
    bool required = false,
    int? limit,
    TextInputType? keyboard,
  }) => Input(
    key: ValueKey('supplier-$key'),
    controller: controller,
    name: label,
    require: required,
    maxLength: limit,
    readOnly: locked,
    keyboardType: keyboard,
  );

  @override
  Widget build(BuildContext context) => GetBuilder<_SupplierFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !widget.c.saving.value,
        child: Main(
          initState: () async => '',
          header: Header.page(
            context,
            text: updating
                ? 'ویرایش ${widget.c.type.singular}'
                : '${widget.c.type.singular} جدید',
          ),
          child: (_) => Obx(
            () => Column(
              children: [
                if (widget.c.saving.value) const LinearProgressIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        IgnorePointer(
                          ignoring: locked,
                          child: MyTab(
                            tab: const ['حقیقی', 'حقوقی'],
                            value: _page.kind,
                            callback: (String value) =>
                                _page.kind.value = value,
                          ),
                        ),
                        if (_page.kind.value.isEmpty)
                          Text('نوع ${widget.c.type.singular} را انتخاب کنید.'),
                        input(
                          'name',
                          'نام ${widget.c.type.singular}',
                          _page.name,
                          required: true,
                          limit: 200,
                        ),
                        input(
                          'phone',
                          'شماره موبایل',
                          _page.phone,
                          required: true,
                          limit: 14,
                          keyboard: TextInputType.phone,
                        ),
                        if (_page.kind.value == 'حقوقی')
                          input(
                            'legalName',
                            labels['legalName']!,
                            _page.fields['legalName']!,
                            required: true,
                            limit: 200,
                          ),
                        ExpansionTile(
                          title: const Text('سایر مشخصات'),
                          children: [
                            for (final field in labels.entries)
                              if (field.key != 'legalName' &&
                                  _page.fields.containsKey(field.key))
                                input(
                                  field.key,
                                  field.value,
                                  _page.fields[field.key]!,
                                  limit: limits[field.key],
                                  keyboard: field.key == 'email'
                                      ? TextInputType.emailAddress
                                      : field.key == 'telephone'
                                      ? TextInputType.phone
                                      : TextInputType.text,
                                ),
                          ],
                        ),
                        if (widget.c.type != AccountingPersonType.partner) ...[
                          MyDivider(),
                          const Text('آدرس‌ها'),
                          for (final address in _page.addresses)
                            ExpansionTile(
                              key: ValueKey(address.id),
                              title: Text(
                                address.fields['title']!.text.isEmpty
                                    ? 'آدرس جدید'
                                    : address.fields['title']!.text,
                              ),
                              children: [
                                for (final field
                                    in _SupplierAddress.labels.entries)
                                  if (![
                                    'provinceCode',
                                    'cityCode',
                                  ].contains(field.key))
                                    input(
                                      '${address.id}-${field.key}',
                                      field.value,
                                      address.fields[field.key]!,
                                      required: [
                                        'title',
                                        'fullAddress',
                                      ].contains(field.key),
                                      limit: _SupplierAddress.limits[field.key],
                                      keyboard:
                                          [
                                            'latitude',
                                            'longitude',
                                          ].contains(field.key)
                                          ? const TextInputType.numberWithOptions(
                                              decimal: true,
                                              signed: true,
                                            )
                                          : TextInputType.text,
                                    ),
                                MiniBTN(
                                  name: address.isDefault
                                      ? 'آدرس پیش‌فرض'
                                      : 'انتخاب به عنوان پیش‌فرض',
                                  icon: IconsaxPlusLinear.tick_circle,
                                  noFlex: true,
                                  onTap: locked
                                      ? null
                                      : () {
                                          final selected = !address.isDefault;
                                          for (final row in _page.addresses) {
                                            row.isDefault = false;
                                          }
                                          address.isDefault = selected;
                                          _page.update();
                                        },
                                ),
                                MiniBTN(
                                  name: 'حذف آدرس',
                                  icon: IconsaxPlusLinear.trash,
                                  noFlex: true,
                                  onTap: locked
                                      ? null
                                      : () {
                                          _page.addresses.remove(address);
                                          _page.removedAddresses.add(address);
                                          _page.update();
                                        },
                                ),
                              ],
                            ),
                          if (_page.addresses.length < 10)
                            MiniBTN(
                              name: 'افزودن آدرس',
                              icon: IconsaxPlusLinear.add,
                              noFlex: true,
                              onTap: locked
                                  ? null
                                  : () {
                                      _page.addresses.add(
                                        _SupplierAddress({
                                          'addressId': const Uuid().v4(),
                                          'countryCode': 'IR',
                                          'isDefault': false,
                                        }),
                                      );
                                      _page.update();
                                    },
                            ),
                        ],
                        if (updating) ...[
                          MyDivider(),
                          IgnorePointer(
                            ignoring: locked,
                            child: MyTab(
                              tab: const ['فعال', 'آرشیو'],
                              value: _page.status,
                              callback: (String value) =>
                                  _page.status.value = value,
                            ),
                          ),
                        ],
                        if (widget.c.commandError.value != null)
                          Text(
                            widget.c.commandError.value!,
                            textAlign: TextAlign.center,
                          ),
                        if (widget.c.pending.value != null)
                          const Text(
                            'نتیجه درخواست قبلی مشخص نیست؛ همان اطلاعات دوباره ارسال می‌شود.',
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: BTN(
                        name: widget.c.pending.value != null
                            ? 'تلاش مجدد ثبت'
                            : updating
                            ? 'ویرایش'
                            : 'افزودن',
                        disabled: widget.c.saving.value,
                        onTap: save,
                      ),
                    ),
                    if (!updating && widget.c.pending.value == null)
                      Flexible(
                        child: BTN(
                          name: 'افزودن و ادامه',
                          disabled: widget.c.saving.value,
                          onTap: () => save(another: true),
                        ),
                      ),
                    Flexible(
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
  void didUpdateWidget(covariant SupplierFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

// Own each address's controllers for the lifetime of the form, including removed rows.
class _SupplierAddress {
  static const labels = {
    'title': 'عنوان آدرس',
    'recipientName': 'نام گیرنده',
    'recipientPhone': 'موبایل گیرنده',
    'countryCode': 'کد کشور',
    'provinceCode': 'کد استان',
    'provinceName': 'استان',
    'cityCode': 'کد شهر',
    'cityName': 'شهر',
    'district': 'منطقه',
    'fullAddress': 'متن آدرس',
    'postalCode': 'کدپستی',
    'latitude': 'عرض جغرافیایی',
    'longitude': 'طول جغرافیایی',
  };
  static const limits = {
    'title': 100,
    'recipientName': 200,
    'recipientPhone': 14,
    'countryCode': 2,
    'provinceCode': 32,
    'provinceName': 100,
    'cityCode': 32,
    'cityName': 100,
    'district': 100,
    'fullAddress': 1000,
    'postalCode': 10,
  };
  final String id;
  late final Map<String, TextEditingController> fields;
  bool isDefault;
  _SupplierAddress(Map<String, dynamic> row)
    : id = row['addressId'] as String,
      isDefault = row['isDefault'] == true {
    fields = {
      for (final key in labels.keys)
        key: TextEditingController(text: row[key]?.toString() ?? ''),
    };
  }
  Map<String, dynamic> body() => {
    'addressId': id,
    'isDefault': isDefault,
    for (final field in fields.entries)
      if (field.value.text.trim().isNotEmpty)
        field.key: ['latitude', 'longitude'].contains(field.key)
            ? double.tryParse(field.value.text.trim().toEnglishDigit()) ??
                  (throw const FormatException('مختصات آدرس باید عدد باشد.'))
            : field.value.text.trim(),
  };
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
  }
}

Widget buildSuppliersRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return SuppliersScreen(
    appId: args.required<String>('appId'),
    type:
        args.optional<AccountingPersonType>('type') ??
        AccountingPersonType.supplier,
  );
}

Widget buildSupplierFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return SupplierFormScreen(
    c: args.required<SuppliersController>('c'),
    item: args.optional<RemoteSupplier>('item'),
  );
}
