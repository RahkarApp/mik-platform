part of '../screen.dart';

class ProductPropertyTabDashboard extends StatefulWidget {
  final String appId;
  final ProductPropertyTabDashboardController? controller;
  const ProductPropertyTabDashboard({
    super.key,
    this.appId = 'mik',
    this.controller,
  });
  @override
  State<ProductPropertyTabDashboard> createState() =>
      _ProductPropertyTabDashboardState();
}

class _ProductPropertyTabDashboardState
    extends State<ProductPropertyTabDashboard> {
  late final c = widget.controller ?? productPropertyTabDashboardController;
  @override
  void initState() {
    super.initState();
    c.detach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        c.attach(widget.appId, search: productDashboardController.search.value);
      }
    });
  }

  @override
  void dispose() {
    c.detach();
    super.dispose();
  }

  Future<void> edit([PimAttribute? item]) async {
    c.commandError.value = null;
    await Get.toNamed(
      nav_routes.RoutesName.PRODUCT_ATTRIBUTE_FORM,
      arguments: {'controller': c, 'item': item},
      preventDuplicates: false,
    );
    if (mounted) await c.init();
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: 45,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.only(right: 10),
                    child: const Text(
                      'ویژگی‌ محصولات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: c.showArchived.value
                        ? 'نمایش فعال‌ها'
                        : 'نمایش آرشیو',
                    icon: const Icon(IconsaxPlusLinear.refresh),
                    onPressed: c.saving.value
                        ? null
                        : () => c.showArchived.toggle(),
                  ),
                ],
              ),
            ),
            if (c.showArchived.value) const Text('ویژگی‌های آرشیوشده'),
            if (c.commandError.value != null) Text(c.commandError.value!),
            if (c.saving.value) const Text('در حال ذخیرهٔ ویژگی…'),
            if (c.conflict.value)
              BTN(
                name: 'دریافت نسخه جدید ویژگی‌ها',
                icon: IconsaxPlusLinear.refresh,
                onTap: c.init,
              ),
            if (c.pending.value != null) ...[
              const Text(
                'یک درخواست تعیین‌تکلیف‌نشده وجود دارد؛ ثبت تازه تا روشن شدن نتیجه انجام نمی‌شود.',
              ),
              if (c.pendingHere)
                BTN(
                  name: 'تلاش مجدد همان درخواست ویژگی',
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
              child: c.loading.value
                  ? const Center(child: CircularProgressIndicator())
                  : c.error.value != null
                  ? ErrorSection(c.error.value, act: c.init)
                  : RefreshIndicator(
                      onRefresh: c.init,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 65),
                        children: [
                          if (c.visible.isEmpty)
                            EmptyList(
                              text: 'ویژگی با این مشخصات موجود نیست!',
                              icon: IconsaxPlusLinear.shapes,
                            )
                          else
                            for (final item in c.visible)
                              PropertyItem(
                                item,
                                controller: c,
                                onEdit: () => edit(item),
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
              text: 'ویژگی جدید',
              onTap: () => edit(),
            ),
          ),
      ],
    ),
  );
}
