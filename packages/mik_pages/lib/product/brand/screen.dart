import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/models/models.dart';

import 'controller.dart';

class ProductBrandsScreen extends StatefulWidget {
  final String appId;
  final ProductBrandController? controller;
  const ProductBrandsScreen({super.key, this.appId = 'mik', this.controller});
  @override
  State<ProductBrandsScreen> createState() => _ProductBrandsScreenState();
}

class _ProductBrandsScreenState extends State<ProductBrandsScreen> {
  late final c = widget.controller ?? ProductBrandController();
  @override
  void initState() {
    super.initState();
    c.detach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.attach(widget.appId);
    });
  }

  Future<void> edit([PimBrand? item]) async {
    c.commandError.value = null;
    await Get.toNamed(
      nav_routes.RoutesName.PRODUCT_BRAND_FORM,
      arguments: {'controller': c, 'item': item},
      preventDuplicates: false,
    );
    if (mounted) await c.init();
  }

  void status(PimBrand item) {
    Confirm.con(
      context,
      type: ConfirmType.CHANGE,
      subtext:
          '${item.status == 'ACTIVE' ? 'آرشیو' : 'فعال‌سازی'} برند «${item.name}» انجام شود؟',
      confirmText: 'تأیید',
      onTapConfirm: () {
        Get.back();
        c.changeStatus(item);
      },
    );
  }

  @override
  void dispose() {
    c.detach();
    if (widget.controller == null) c.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !c.saving.value,
      child: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.error.value != null) {
          return ErrorSection(c.error.value, act: c.init);
        }
        return Stack(
          children: [
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BTN(
                        name: c.showArchived.value
                            ? 'نمایش فعال‌ها'
                            : 'نمایش آرشیو',
                        icon: IconsaxPlusLinear.refresh,
                        disabled: c.saving.value,
                        borderOnly: true,
                        onTap: () => c.showArchived.toggle(),
                      ),
                    ),
                  ],
                ),
                if (c.commandError.value != null) Text(c.commandError.value!),
                if (c.conflict.value)
                  BTN(
                    name: 'دریافت نسخه جدید برندها',
                    icon: IconsaxPlusLinear.refresh,
                    onTap: c.init,
                  ),
                if (c.pending.value != null) ...[
                  const Text('درخواست قبلی باید تعیین تکلیف شود.'),
                  if (c.pendingHere)
                    BTN(
                      name: 'تلاش مجدد همان درخواست برند',
                      icon: IconsaxPlusLinear.refresh,
                      onTap: c.resume,
                      disabled: c.saving.value,
                    )
                  else
                    const Text(
                      'درخواست باز مربوط به عملیات دیگری است؛ آن را در صفحهٔ مربوط ادامه دهید.',
                    ),
                ],
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: c.init,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 65),
                      children: [
                        if (c.visible.isEmpty)
                          const Center(
                            child: Text('برندی با این مشخصات موجود نیست.'),
                          ),
                        for (final item in c.visible)
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyDivider(text: item.name),
                                if (item.latinName != null)
                                  Text(item.latinName!),
                                if (item.description != null)
                                  Text(item.description!),
                                if (item.website != null) Text(item.website!),
                                Row(
                                  children: [
                                    if (c.canEdit(item))
                                      MiniBTN(
                                        name: 'ویرایش',
                                        icon: IconsaxPlusLinear.edit,
                                        onTap: () => edit(item),
                                      ),
                                    if (c.canStatus(item))
                                      MiniBTN(
                                        name: item.status == 'ACTIVE'
                                            ? 'آرشیو'
                                            : 'فعال‌سازی',
                                        icon: IconsaxPlusLinear.refresh,
                                        onTap: () => status(item),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
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
                  text: 'برند جدید',
                  onTap: () => edit(),
                ),
              ),
          ],
        );
      }),
    ),
  );
}

class ProductBrandForm extends StatefulWidget {
  final ProductBrandController controller;
  final PimBrand? item;
  const ProductBrandForm({super.key, required this.controller, this.item});
  @override
  State<ProductBrandForm> createState() => _ProductBrandFormState();
}

class _ProductBrandFormController extends GetxController {
  final name = TextEditingController(),
      latin = TextEditingController(),
      description = TextEditingController(),
      website = TextEditingController();
  PimBrand? item;
}

class _ProductBrandFormState extends State<ProductBrandForm> {
  late final _page = _ProductBrandFormController();

  ProductBrandController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    fill(widget.item);
  }

  void fill(PimBrand? value) {
    _page.item = value;
    _page.name.text = value?.name ?? '';
    _page.latin.text = value?.latinName ?? '';
    _page.description.text = value?.description ?? '';
    _page.website.text = value?.website ?? '';
  }

  Future<void> reload() async {
    await c.init();
    if (!mounted || c.error.value != null) return;
    final latest = c.pro.where((v) => v.id == _page.item?.id).firstOrNull;
    if (latest == null) {
      c.commandError.value = 'برند دیگر در دسترس نیست.';
      return;
    }
    {
      fill(latest);
      _page.update();
    }
  }

  @override
  void dispose() {
    for (final v in [
      _page.name,
      _page.latin,
      _page.description,
      _page.website,
    ]) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_ProductBrandFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => PopScope(
        canPop: !c.saving.value,
        child: Main(
          initState: () async => true,
          header: Header.page(
            context,
            text: _page.item == null ? 'برند جدید' : 'ویرایش برند',
            help: false,
          ),
          child: (_) => Obx(
            () => ListView(
              padding: const EdgeInsets.all(10),
              children: [
                AbsorbPointer(
                  absorbing: c.locked,
                  child: Column(
                    children: [
                      MyDivider(text: 'مشخصات برند'),
                      Input(
                        key: const ValueKey('brand-name'),
                        controller: _page.name,
                        name: 'نام برند',
                        require: true,
                        maxLength: 200,
                      ),
                      Input(
                        controller: _page.latin,
                        name: 'نام لاتین (اختیاری)',
                        maxLength: 200,
                      ),
                      Input(
                        controller: _page.website,
                        name: 'وب‌سایت (اختیاری)',
                        maxLength: 1000,
                      ),
                      Input(
                        controller: _page.description,
                        name: 'توضیحات (اختیاری)',
                        maxLength: 10000,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                if (c.commandError.value != null) Text(c.commandError.value!),
                if (c.error.value != null) Text(c.error.value!),
                if (c.conflict.value)
                  BTN(name: 'دریافت نسخه جدید و جایگزینی فرم', onTap: reload)
                else if (c.pending.value != null)
                  const Text(
                    'برای ادامهٔ همان درخواست قبلی به صفحهٔ برندها برگردید.',
                  )
                else
                  BTN(
                    name: 'ذخیره برند',
                    disabled:
                        c.locked ||
                        _page.item != null && !c.canEdit(_page.item!),
                    onTap: () async {
                      if (await c.save(
                            item: _page.item,
                            name: _page.name.text,
                            latinName: _page.latin.text,
                            description: _page.description.text,
                            website: _page.website.text,
                          ) &&
                          mounted) {
                        Get.back(result: true);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget buildProductBrandFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductBrandForm(
    controller: args.required<ProductBrandController>('controller'),
    item: args.optional<PimBrand>('item'),
  );
}
