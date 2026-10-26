part of '../../screen.dart';

class AddCategoryForm extends StatefulWidget {
  final CatTabDashboardController controller;
  final PimCategory? item;
  const AddCategoryForm({super.key, required this.controller, this.item});
  @override
  State<AddCategoryForm> createState() => _AddCategoryFormState();
}

class _AddCategoryFormController extends GetxController {
  final name = TextEditingController(), description = TextEditingController();
  String? parentId;
}

class _AddCategoryFormState extends State<AddCategoryForm> {
  late final _page = _AddCategoryFormController();

  CatTabDashboardController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _page.name.text = widget.item?.name ?? '';
    _page.description.text = widget.item?.description ?? '';
    _page.parentId = widget.item?.parentId;
  }

  @override
  void dispose() {
    _page.name.dispose();
    _page.description.dispose();
    super.dispose();
  }

  Future<void> save(bool close) async {
    if (await c.saveCategory(
          item: widget.item,
          name: _page.name.text,
          description: _page.description.text,
          parentId: _page.parentId,
        ) &&
        mounted) {
      if (close) {
        Get.back(result: true);
      } else {
        {
          _page.name.clear();
          _page.description.clear();
          _page.parentId = null;
          _page.update();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_AddCategoryFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(() {
      final parents = [
        if (widget.item?.source == 'CATALOG')
          const ItemValue(text: 'بدون والد', data: null),
        for (final p in c.parents(widget.item))
          ItemValue(text: p.name, data: p.id),
      ];
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            const SizedBox(height: 8),
            Input(
              name: 'نام دسته‌بندی',
              require: true,
              controller: _page.name,
              enabled: !c.locked,
              maxLength: 200,
            ),
            Input(
              name: 'توضیحات',
              minLines: 2,
              maxLines: 2,
              controller: _page.description,
              enabled: !c.locked,
              maxLength: 10000,
            ),
            Dropdown(
              name: 'انتخاب دسته‌بندی والد',
              require: widget.item?.source != 'CATALOG',
              itemValue: true,
              items_Value: parents,
              disable: c.locked,
              defaultValue: parents
                  .where((v) => v.data == _page.parentId)
                  .firstOrNull,
              onChange: (value) {
                _page.parentId = (value as ItemValue).data as String?;
                _page.update();
              },
            ),
            if (c.parents(widget.item).isEmpty &&
                widget.item?.source != 'CATALOG')
              const Text(
                'ابتدا یک دسته از پیش‌فرض‌ها اضافه یا یک دستهٔ والد را فعال کنید.',
              ),
            if (c.commandError.value != null) Text(c.commandError.value!),
            if (c.conflict.value)
              BTN(
                name: 'دریافت نسخه جدید دسته‌بندی‌ها',
                onTap: () async {
                  await c.init();
                  if (mounted) Get.back();
                },
              )
            else if (c.pending.value != null) ...[
              const Text(
                'ابتدا نتیجهٔ درخواست قبلی را در تب دسته‌بندی‌ها تعیین تکلیف کنید.',
              ),
              MiniBTN(
                name: 'بازگشت به دسته‌بندی‌ها',
                icon: IconsaxPlusLinear.refresh,
                noFlex: true,
                onTap: c.saving.value
                    ? null
                    : () => Get.back(),
              ),
            ] else
              Row(
                children: [
                  Flexible(
                    child: BTN(
                      name: widget.item == null
                          ? 'افزودن و بازگشت'
                          : 'ذخیره تغییرات',
                      color: AppColors.primaryDark,
                      disabled: c.locked,
                      onTap: () => save(true),
                    ),
                  ),
                  if (widget.item == null)
                    Flexible(
                      child: BTN(
                        name: 'افزودن و ادامه',
                        borderOnly: true,
                        color: AppColors.primaryDark,
                        disabled: c.locked,
                        onTap: () => save(false),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    }),
  );
}
