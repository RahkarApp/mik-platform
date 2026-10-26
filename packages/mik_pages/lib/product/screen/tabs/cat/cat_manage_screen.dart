part of '../../screen.dart';

class CatManageScreen extends StatefulWidget {
  final CatTabDashboardController controller;
  final PimCategory? item;
  const CatManageScreen({super.key, required this.controller, this.item});
  @override
  State<CatManageScreen> createState() => _CatManageScreenState();
}

class _CatManageScreenState extends State<CatManageScreen> {
  CatTabDashboardController get c => widget.controller;
  final index = 0.obs, search = ''.obs;
  final textCTL = TextEditingController();
  @override
  void initState() {
    super.initState();
    index.value = c.canImport ? 0 : 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.item == null && c.canImport) c.loadCatalog();
    });
  }

  @override
  void dispose() {
    textCTL.dispose();
    super.dispose();
  }

  bool matches(CatalogCategory item, Set<String> visited) {
    if (!visited.add(item.id)) return false;
    final q = c.normalize(search.value);
    return q.isEmpty ||
        c.normalize(item.name).contains(q) ||
        item.id.contains(q) ||
        (c.catalog[item.id] ?? []).any((v) => matches(v, visited));
  }

  Widget catalogNode(CatalogCategory item) => ExpansionTile(
    key: ValueKey('catalog-${item.id}-${search.value}'),
    initiallyExpanded: search.value.isNotEmpty,
    title: Text(item.name),
    leading: Icon(
      IconsaxPlusLinear.data_2,
      color: AppColors.grey.withValues(alpha: 0.5),
      size: 18,
    ),
    onExpansionChanged: (expanded) {
      if (expanded) c.loadCatalog(parent: item.id);
    },
    children: [
      BTN(
        name: 'افزودن ${item.name}',
        icon: IconsaxPlusLinear.add,
        onTap: () => Confirm.con(
          context,
          type: ConfirmType.SAVE,
          subtext: 'این دسته، زیر‌دسته‌ها و والدهای موردنیاز از فهرست سرور اضافه شوند؟ دسته‌های موجود بازنویسی یا خودکار فعال نمی‌شوند.',
          confirmText: 'افزودن دسته‌های پیش‌فرض',
          onTapConfirm: () async {
            Get.back();
            await c.importCategory(item);
          },
        ),
        disabled: !c.canImport,
        navigate: true,
      ),
      if (c.catalogLoading.contains(item.id)) const CircularProgressIndicator(),
      if (c.catalogErrors[item.id] != null)
        ErrorSection(
          c.catalogErrors[item.id],
          act: () => c.loadCatalog(parent: item.id),
        ),
      for (final child in c.catalog[item.id] ?? <CatalogCategory>[])
        if (matches(child, {}))
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: catalogNode(child),
          ),
    ],
  );
  @override
  Widget build(BuildContext context) => Obx(
    () => PopScope(
      canPop: !c.saving.value,
      child: Main(
        initState: () async => true,
        header: Header.page(
          context,
          text: widget.item == null
              ? 'مدیریت دسته‌بندی‌ها'
              : 'ویرایش دسته‌بندی',
        ),
        child: (_) => widget.item != null
            ? AddCategoryForm(controller: c, item: widget.item)
            : Column(
                children: [
                  MyTabBar(
                    tabs: const ['انتخاب از پیش‌فرض‌ها', 'افزودن سفارشی'],
                    currentIndex: index.value,
                    index: (value) {
                      if (c.saving.value) return;
                      index.value = value;
                      search.value = '';
                      textCTL.clear();
                      MySearchBarController.unfoces();
                      if (value == 0 && c.canImport) c.loadCatalog();
                    },
                  ),
                  if (index.value == 0)
                    MySearchBar(
                      controller: textCTL,
                      enableScanner: false,
                      type: SearchBarType.category,
                      callback: (value) => search.value = value.toString(),
                    ),
                  Expanded(
                    child: Obx(() {
                      if (index.value == 1) {
                        return c.fx?.has('pim.product.category.create') == true
                            ? AddCategoryForm(controller: c)
                            : const Center(
                                child: Text(
                                  'اجازهٔ افزودن دسته‌بندی سفارشی را ندارید.',
                                ),
                              );
                      }
                      if (c.fx?.has('pim.product.category.import') != true) {
                        return const Center(
                          child: Text(
                            'اجازهٔ افزودن از دسته‌بندی‌های پیش‌فرض را ندارید.',
                          ),
                        );
                      }
                      return ListView(
                        children: [
                          const Text(
                            'شاخه‌ها را باز کنید؛ جست‌وجو در شاخه‌های دریافت‌شده انجام می‌شود.',
                          ),
                          if (c.notice.value != null) Text(c.notice.value!),
                          if (c.commandError.value != null)
                            Text(c.commandError.value!),
                          if (c.pending.value != null)
                            const Text(
                              'برای ادامهٔ درخواست قبلی به تب دسته‌بندی‌ها برگردید.',
                            ),
                          if (c.catalogLoading.contains(''))
                            const Center(child: CircularProgressIndicator()),
                          if (c.catalogErrors[''] != null)
                            ErrorSection(
                              c.catalogErrors[''],
                              act: c.loadCatalog,
                            ),
                          for (final item
                              in c.catalog[''] ?? <CatalogCategory>[])
                            if (matches(item, {})) catalogNode(item),
                        ],
                      );
                    }),
                  ),
                ],
              ),
      ),
    ),
  );
}
