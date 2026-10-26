import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/citiesInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/city.dart';
import 'package:mik_data/utils/fx/customers.dart';
import 'package:mik_utils/public/city.dart';

import 'customer_controller.dart';

class CustomerFormScreen extends StatefulWidget {
  final CustomersFX fx;
  final String? customerId;
  const CustomerFormScreen({required this.fx, this.customerId, super.key});
  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenController extends GetxController {
  _CustomerFormScreenController(this.widget);
  CustomerFormScreen widget;
  late final c = CustomerEditorController(fx: widget.fx, id: widget.customerId);
  final personKind = 'حقیقی'.obs;
  bool changed = false;
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  late final _page = _CustomerFormScreenController(widget);

  @override
  void dispose() {
    _page.c.onClose();
    super.dispose();
  }

  Future<Object> load() async {
    await _page.c.load();
    if (mounted) {
      _page.personKind.value = _page.c.kind.value == 'ORGANIZATION'
          ? 'حقوقی'
          : 'حقیقی';
    }
    return '';
  }

  Widget input(
    String key,
    String name, {
    bool required = false,
    int? lines,
    TextInputType? keyboard,
    double? rightPadding,
  }) => Input(
    key: ValueKey('customer-$key'),
    controller: _page.c.fields[key]!,
    name: name,
    require: required,
    readOnly: _page.c.locked || !_page.c.canSave,
    minLines: lines,
    maxLines: lines ?? 1,
    keyboardType: keyboard,
    rightPadding: rightPadding,
  );
  Future<void> save({bool another = false}) async {
    final result = await _page.c.save();
    if (!mounted || result == null) return;
    _page.changed = true;
    if (!another || widget.customerId != null) {
      Get.back(result: true);
      return;
    }
    for (final field in _page.c.fields.values) {
      field.clear();
    }
    await load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_CustomerFormScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      // REST failures are shown by the controller; legacy socket state is unrelated.
      initState: load,
      header: Header.page(
        context,
        text: widget.customerId == null ? 'مشتری جدید' : 'مشخصات مشتری',
      ),
      child: (_) => Obx(
        () => Column(
          children: [
            if (_page.c.loading.value || _page.c.saving.value)
              const LinearProgressIndicator(),
            if (_page.c.error.value != null)
              Text(_page.c.error.value!, textAlign: TextAlign.center),
            if (!_page.c.ready.value || _page.c.conflict.value)
              MiniBTN(
                name: _page.c.conflict.value ? 'دریافت نسخه جدید' : 'تلاش مجدد',
                noFlex: true,
                icon: IconsaxPlusLinear.refresh,
                onTap: _page.c.loading.value || _page.c.saving.value
                    ? null
                    : load,
              ),
            if (_page.c.pending.value != null)
              const Text(
                'نتیجه درخواست قبلی مشخص نیست؛ تلاش مجدد با همان اطلاعات انجام می‌شود.',
                textAlign: TextAlign.center,
              ),
            if (_page.c.ready.value && !_page.c.canSave)
              Text(
                _page.c.item.value?.isDefault == true
                    ? 'مشخصات مشتری متفرقه قابل ویرایش نیست.'
                    : 'مجوز ویرایش این مشتری را ندارید؛ مشخصات فقط خواندنی است.',
                textAlign: TextAlign.center,
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    IgnorePointer(
                      ignoring: _page.c.locked || !_page.c.canSave,
                      child: MyTab(
                        tab: const ['حقیقی', 'حقوقی'],
                        value: _page.personKind,
                        callback: (value) {
                          _page.personKind.value = value;
                          _page.c.kind.value = value == 'حقوقی'
                              ? 'ORGANIZATION'
                              : 'PERSON';
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    input(
                      'name',
                      _page.c.kind.value == 'ORGANIZATION'
                          ? 'نام شرکت'
                          : 'نام‌ونام‌خانوادگی',
                      required: true,
                    ),
                    if (_page.c.kind.value == 'ORGANIZATION') ...[
                      input(
                        'contactName',
                        'نام‌ونام‌خانوادگی رابط',
                        rightPadding: 120,
                      ),
                      input(
                        'telephone',
                        'تلفن شرکت',
                        keyboard: TextInputType.phone,
                      ),
                      input(
                        'nationalId',
                        'شناسه‌ملی',
                        keyboard: TextInputType.number,
                      ),
                      input(
                        'economicCode',
                        'کداقتصادی',
                        keyboard: TextInputType.number,
                      ),
                    ],
                    input(
                      'phone',
                      'تلفن همراه',
                      required: true,
                      keyboard: TextInputType.phone,
                    ),
                    ExpansionTile(
                      title: const Text(
                        'برای وارد کردن سایر اطلاعات اینجا را لمس کنید',
                      ),
                      children: [
                        if (_page.c.kind.value == 'PERSON')
                          input(
                            'nationalId',
                            'کدملی',
                            keyboard: TextInputType.number,
                          ),
                        input(
                          'email',
                          'ایمیل',
                          keyboard: TextInputType.emailAddress,
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: IgnorePointer(
                                ignoring: _page.c.locked || !_page.c.canSave,
                                child: SelectListInput(
                                  controller: _page.c.fields['provinceName']!,
                                  list: provinces,
                                  name: 'استان',
                                  onChanged: (value) {
                                    _page.c.fields['provinceName']!.text =
                                        value;
                                    _page.c.fields['cityName']!.clear();
                                    _page.update();
                                  },
                                ),
                              ),
                            ),
                            if (_page.c.fields['provinceName']!.text.isNotEmpty)
                              Flexible(
                                child: IgnorePointer(
                                  ignoring: _page.c.locked || !_page.c.canSave,
                                  child: SelectListInput(
                                    controller: _page.c.fields['cityName']!,
                                    list:
                                        City.city(
                                          _page.c.fields['provinceName']!.text,
                                        ) ??
                                        [],
                                    name: 'شهر',
                                    onChanged: (value) =>
                                        _page.c.fields['cityName']!.text =
                                            value,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        input('title', 'عنوان آدرس'),
                        input('fullAddress', 'ادامه آدرس', lines: 2),
                        input(
                          'postalCode',
                          'کدپستی',
                          keyboard: TextInputType.number,
                        ),
                        input('description', 'توضیحات', lines: 3),
                        const Text(
                          'اطلاعات بانکی و شبکه‌های اجتماعی در قرارداد فعلی مشتری پشتیبانی نمی‌شوند.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (widget.customerId != null &&
                _page.c.ready.value &&
                [
                  'ucrm.interaction.read',
                  'ucrm.interaction.read.all',
                  'ucrm.followup.read',
                  'ucrm.followup.read.all',
                ].any(widget.fx.has))
              MiniBTN(
                name: 'ارتباطات و پیگیری‌ها',
                icon: IconsaxPlusLinear.call_calling,
                noFlex: true,
                onTap:
                    _page.c.loading.value ||
                        _page.c.saving.value ||
                        _page.c.pending.value != null
                    ? null
                    : () => Get.toNamed(
                        nav_routes.RoutesName.CUSTOMER_CRM,
                        arguments: {
                          'appId': widget.fx.context.auth.appId,
                          'customerId': widget.customerId,
                        },
                        preventDuplicates: false,
                      ),
              ),
            Row(
              children: [
                if (_page.c.canSave)
                  Flexible(
                    child: BTN(
                      name: _page.c.pending.value != null
                          ? 'تلاش مجدد ثبت'
                          : widget.customerId == null
                          ? 'افزودن'
                          : 'ویرایش',
                      disabled:
                          !_page.c.ready.value ||
                          _page.c.loading.value ||
                          _page.c.saving.value ||
                          _page.c.conflict.value,
                      onTap: save,
                    ),
                  ),
                if (_page.c.canSave &&
                    widget.customerId == null &&
                    _page.c.pending.value == null)
                  Flexible(
                    child: BTN(
                      name: 'افزودن و ادامه',
                      disabled:
                          !_page.c.ready.value ||
                          _page.c.loading.value ||
                          _page.c.saving.value,
                      onTap: () => save(another: true),
                    ),
                  ),
                Flexible(
                  child: BTN(
                    name: 'انصراف',
                    type: BTNType.cancel,
                    disabled: _page.c.saving.value,
                    onTap: () => Get.back(result: _page.changed),
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
  void didUpdateWidget(covariant CustomerFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

Widget buildCustomerFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return CustomerFormScreen(
    fx: args.required<CustomersFX>('fx'),
    customerId: args.optional<String>('customerId'),
  );
}
