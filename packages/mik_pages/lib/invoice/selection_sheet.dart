import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

/// The old person input layout, using remote identities supplied by its caller.
class InvoicePersonItem extends StatelessWidget {
  final String name, role, icon;
  final String? phone;
  final VoidCallback onTap;
  const InvoicePersonItem({
    super.key,
    required this.name,
    required this.phone,
    required this.role,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Obx(
      () => Column(
        children: [
          SizedBox(
            height: 45,
            child: Row(
              children: [
                CircleAvatar(
                  maxRadius: 15,
                  backgroundColor: AppColors.boxBackground,
                  child: SvgPicture.asset(
                    icon,
                    width: 20,
                    errorBuilder: (_, _, _) =>
                        const Icon(IconsaxPlusLinear.user, size: 20),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: MyTextScroll(
                    phone == null || phone!.isEmpty ? name : '$name ($phone)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkMode.isTrue ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 16,
                    color: darkMode.isTrue ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(right: 30),
            color: darkMode.isTrue
                ? Colors.grey.shade600
                : Colors.grey.shade300,
          ),
        ],
      ),
    ),
  );
}

Future<BusinessWarehouse?> selectInvoiceWarehouse(
  BuildContext context, {
  required List<BusinessWarehouse> warehouses,
  required String branchName,
  String? selectedId,
}) async {
  return await MyBottomSheet.view(
    context,
    title: 'انتخاب انبار',
    initialChildSize: 0.8,
    child: (scroll) => _InvoiceWarehousePicker(
      warehouses: warehouses,
      branchName: branchName,
      selectedId: selectedId,
      scroll: scroll,
    ),
  ) as BusinessWarehouse?;
}

class _InvoiceWarehousePicker extends StatefulWidget {
  final List<BusinessWarehouse> warehouses;
  final String branchName;
  final String? selectedId;
  final ScrollController scroll;
  const _InvoiceWarehousePicker({
    required this.warehouses,
    required this.branchName,
    required this.selectedId,
    required this.scroll,
  });
  @override
  State<_InvoiceWarehousePicker> createState() =>
      _InvoiceWarehousePickerState();
}

class _InvoiceWarehousePickerController extends GetxController {
  final search = TextEditingController();
  String query = '';
}

class _InvoiceWarehousePickerState extends State<_InvoiceWarehousePicker> {
  late final _page = _InvoiceWarehousePickerController();

  @override
  void dispose() {
    _page.search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_InvoiceWarehousePickerController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final rows = widget.warehouses.where(
          (row) => '${row.name} ${widget.branchName}'
              .toLowerCase()
              .toEnglishDigit()
              .contains(_page.query),
        );
        return Obx(
          () => Column(
            children: [
              MySearchBar(
                controller: _page.search,
                type: SearchBarType.warehouse,
                enableScanner: false,
                hintText: 'جستجو',
                callback: (value) {
                  _page.query = value
                      .toString()
                      .trim()
                      .toLowerCase()
                      .toEnglishDigit();
                  _page.update();
                },
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Text(
                          'انبار با این نام وجود ندارد!',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView(
                        controller: widget.scroll,
                        children: [
                          for (final row in rows)
                            InkWell(
                              key: ValueKey(
                                'invoice-warehouse-${row.warehouseId}',
                              ),
                              onTap: () => Get.back(result: row),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 45,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.success,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(10),
                                                  bottomLeft: Radius.circular(
                                                    10,
                                                  ),
                                                ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Icon(
                                                IconsaxPlusLinear.box,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              RotatedBox(
                                                quarterTurns: 1,
                                                child: Text(
                                                  'انبار',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            row.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            widget.branchName,
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                        if (row.warehouseId ==
                                            widget.selectedId)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 5,
                                            ),
                                            child: Icon(
                                              IconsaxPlusLinear.tick_square,
                                              size: 18,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    margin: const EdgeInsets.only(right: 30),
                                    color: darkMode.isTrue
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade300,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              BTN(
                name: 'انصراف',
                type: BTNType.cancel,
                onTap: () => Get.back(),
              ),
            ],
          ),
        );
      },
    );
  }
}
