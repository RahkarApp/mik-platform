import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_components/base/alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_consts/svgIcon.dart';
import 'package:mik_data/source/remote/models/customer.dart';

import 'customer_controller.dart';

class RemoteCustomersTab extends StatefulWidget {
  final RemoteCustomersController controller;
  const RemoteCustomersTab({required this.controller, super.key});
  @override
  State<RemoteCustomersTab> createState() => _RemoteCustomersTabState();
}

class _RemoteCustomersTabState extends State<RemoteCustomersTab> {
  RemoteCustomersController get controller => widget.controller;
  Worker? _readErrors;
  @override
  void initState() {
    super.initState();
    _readErrors = ever(controller.error, (message) {
      if (mounted && message != null) Alert.error(message, context: context);
    });
  }

  @override
  void dispose() {
    _readErrors?.dispose();
    super.dispose();
  }

  Future<void> open(BuildContext context, {RemoteCustomer? item}) async {
    final fx = controller.fx;
    if (fx == null) return;
    try {
      fx.check();
    } catch (_) {
      await controller.load();
      return;
    }
    if (!context.mounted) return;
    controller.editing = true;
    try {
      await Get.toNamed(
        nav_routes.RoutesName.CUSTOMER_FORM,
        arguments: {
          'fx': fx,
          'customerId': fx.pending != null ? fx.pending!.customerId : item?.id,
        },
        preventDuplicates: false,
      );
    } finally {
      controller.editing = false;
    }
    // Refresh even on back: a previous save-and-continue may already have committed.
    await controller.load();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final c = controller;
    final fx = c.fx;
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      floatingActionButton:
          fx != null && (fx.pending != null || fx.has('ucrm.customer.create'))
          ? MyFAB(
              icon: IconsaxPlusLinear.add,
              text: fx.pending != null ? 'ادامه درخواست قبلی' : 'مشتری جدید',
              onTap: () => open(context),
            )
          : null,
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Text(
                  'لیست مشتریان',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const RotatedBox(
                  quarterTurns: 1,
                  child: Icon(IconsaxPlusLinear.setting_5),
                ),
                onPressed: () => MyBottomSheet.view(
                  context,
                  title: '',
                  child: (_) => Column(
                    children: [
                      const Text(
                        'فیلتر نمایش مشتریان',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'فیلتر بدهی و آخرین خرید پس از اتصال اطلاعات مالی فعال می‌شود.',
                      ),
                      BTN(
                        name: 'بستن',
                        navigate: true,
                        onTap: () => Get.back(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (c.loading.value || c.moreLoading.value)
            const LinearProgressIndicator(),
          if (c.searchHint.value != null) Text(c.searchHint.value!),
          if (c.error.value != null) ...[
            Text(c.error.value!, textAlign: TextAlign.center),
            MiniBTN(
              name: 'تلاش مجدد',
              icon: IconsaxPlusLinear.refresh,
              noFlex: true,
              onTap: c.loading.value
                  ? null
                  : () => c.load(more: c.items.isNotEmpty),
            ),
          ],
          Expanded(
            child: c.items.isEmpty
                ? c.loading.value ||
                          c.error.value != null ||
                          c.searchHint.value != null
                      ? const SizedBox.shrink()
                      : EmptyList(
                          text: c.query.isEmpty
                              ? 'هیچ مشتری وجود ندارد!'
                              : 'مشتری با این مشخصات موجود نیست!',
                          icon: IconsaxPlusLinear.user_search,
                        )
                : RefreshIndicator(
                    onRefresh: c.load,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 70),
                      itemCount:
                          c.items.length + (c.next.value == null ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index == c.items.length) {
                          return MiniBTN(
                            name: 'نمایش بیشتر',
                            noFlex: true,
                            icon: IconsaxPlusLinear.arrow_down,
                            onTap: c.moreLoading.value
                                ? null
                                : () => c.load(more: true),
                          );
                        }
                        final item = c.items[index];
                        return InkWell(
                          key: ValueKey(item.id),
                          onTap: () => open(context, item: item),
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
                                      backgroundColor: AppColors.boxBackground,
                                      maxRadius: 25,
                                      child: SvgPicture.asset(
                                        item.kind == 'ORGANIZATION'
                                            ? SvgIcon.orgCustomer
                                            : SvgIcon.customer,
                                        height: 40,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item.name,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                item.phone ??
                                                    'شماره همراه ثبت نشده',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          MiniBTN(
                                            name: 'صورت‌حساب و گردش حساب',
                                            noFlex: true,
                                            icon:
                                                IconsaxPlusLinear.document_text,
                                            onTap: () => Get.toNamed(
                                              nav_routes
                                                  .RoutesName
                                                  .PARTY_ACCOUNT,
                                              arguments: {
                                                'appId': c.appId,
                                                'partyType': 'CUSTOMER',
                                                'partyId': item.id,
                                              },
                                              preventDuplicates: false,
                                                ),
                                          ),
                                          const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('آخرین خرید: نامشخص'),
                                              Text('وضعیت مالی: نامشخص'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (index != c.items.length - 1) EndLine(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  });
}
