part of '../../screen.dart';

class CatTabDashboard extends StatefulWidget {
  final String appId;
  final CatTabDashboardController? controller;
  const CatTabDashboard({super.key, this.appId = 'mik', this.controller});
  @override
  State<CatTabDashboard> createState() => _CatTabDashboardState();
}

class _CatTabDashboardState extends State<CatTabDashboard> {
  late final c = widget.controller ?? catTabDashboardController;
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

  Future<void> edit([PimCategory? item]) async {
    await Get.toNamed(
      nav_routes.RoutesName.CAT_MANAGE,
      arguments: {'controller': c, 'item': item},
      preventDuplicates: false,
    );
    if (mounted) await c.init();
  }

  void status(PimCategory item) {
    Confirm.con(
      context,
      type: ConfirmType.CHANGE,
      subtext: item.status == 'ACTIVE'
          ? 'این دسته‌بندی آرشیو شود؟ دستهٔ دارای محصول یا زیر‌دستهٔ فعال قابل آرشیو نیست.'
          : 'این دسته‌بندی دوباره فعال شود؟',
      confirmText: item.status == 'ACTIVE'
          ? 'آرشیو دسته‌بندی'
          : 'فعال‌سازی دسته‌بندی',
      onTapConfirm: () async {
        Get.back();
        await c.changeStatus(item);
      },
    );
  }

  Widget tree(
    BuildContext context,
    List<PimCategory> rows,
    String? parent,
    Set<String> visible,
  ) => Padding(
    padding: const EdgeInsets.only(right: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in rows.where(
          (v) => parent == null
              ? !visible.contains(v.parentId)
              : v.parentId == parent,
        ))
          if (rows.any((v) => v.parentId == item.id))
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey('${item.id}-${c.query.value}'),
                initiallyExpanded: c.query.value.isNotEmpty,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(right: 20),
                showTrailingIcon: false,
                title: row(item, true),
                children: [tree(context, rows, item.id, visible)],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: row(item, false),
            ),
      ],
    ),
  );
  Widget row(PimCategory item, bool hasChildren) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.boxBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          hasChildren ? IconsaxPlusLinear.data_2 : IconsaxPlusLinear.box,
          size: 24,
          color: AppColors.disable,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              item.id,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      if (c.canEdit(item))
        IconButton(
          icon: Icon(
            IconsaxPlusLinear.edit_2,
            size: 20,
            color: darkMode.isFalse ? Colors.black : Colors.white,
          ),
          tooltip: 'ویرایش',
          onPressed: () => edit(item),
        ),
      if (c.canStatus(item))
        IconButton(
          icon: Icon(
            item.status == 'ACTIVE'
                ? IconsaxPlusLinear.trash
                : IconsaxPlusLinear.refresh,
            size: 20,
            color: darkMode.isFalse ? Colors.black : Colors.white,
          ),
          tooltip: item.status == 'ACTIVE' ? 'آرشیو' : 'فعال‌سازی',
          onPressed: () => status(item),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Obx(
    () => Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.only(right: 10),
                  child: const Text(
                    'دسته‌بندی‌ها',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            if (c.showArchived.value) const Text('دسته‌بندی‌های آرشیوشده'),
            if (c.notice.value != null) Text(c.notice.value!),
            if (c.commandError.value != null) Text(c.commandError.value!),
            if (c.conflict.value)
              BTN(
                name: 'دریافت نسخه جدید دسته‌بندی‌ها',
                icon: IconsaxPlusLinear.refresh,
                onTap: c.init,
              ),
            if (c.pending.value != null) ...[
              const Text(
                'یک درخواست تعیین‌تکلیف‌نشده وجود دارد؛ ثبت تازه تا روشن شدن نتیجه انجام نمی‌شود.',
              ),
              if (c.pendingHere)
                BTN(
                  name: 'تلاش مجدد همان درخواست دسته‌بندی',
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
                        children: [
                          if (c.visibleIds.isEmpty)
                            EmptyList(
                              text: 'دسته‌بندی با این مشخصات موجود نیست!',
                              icon: IconsaxPlusLinear.box_search,
                            )
                          else
                            tree(
                              context,
                              c.cat
                                  .where((v) => c.visibleIds.contains(v.id))
                                  .toList(),
                              null,
                              c.visibleIds,
                            ),
                          const SizedBox(height: 65),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        if (c.canCreate || c.canImport)
          Positioned(
            bottom: 1,
            right: 10,
            child: MyFAB(
              icon: IconsaxPlusLinear.add,
              text: 'دسته‌بندی جدید',
              onTap: () => edit(),
            ),
          ),
      ],
    ),
  );
}
