part of '../screen.dart';

class InvoiceShare extends GetView {
  InvoiceDB item;
  double paid;
  InvoiceShare({required this.item, required this.paid, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: (item.type != 'buy')
          ? Row(
              mainAxisAlignment:
                  paid <
                      (InvoiceFX.price(item) +
                          item.parameters!
                              .map(
                                (r) => r['name'] == 'excess' ? r['amount'] : 0,
                              )
                              .toList()
                              .reduce((a, b) => a + b) -
                          item.parameters!
                              .map(
                                (r) =>
                                    r['name'] == 'discount' ? r['amount'] : 0,
                              )
                              .toList()
                              .reduce((a, b) => a + b))
                  ? MainAxisAlignment.spaceAround
                  : MainAxisAlignment.center,
              children: [
                MiniBTN(
                  icon: IconsaxPlusLinear.receipt_item,
                  itemColor: darkMode.isTrue ? AppColors.grey : null,
                  name: 'فاکتور آنلاین',
                  onTap: () {
                    launchUrlString(
                      "https://onmik.ir/invoice/${item.uid}",
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                if (POSFX.isPos())
                  MiniBTN(
                    icon: IconsaxPlusLinear.printer,
                    itemColor: darkMode.isTrue ? AppColors.grey : null,
                    name: 'چاپ',
                    onTap: () async {
                      Confirm.con(
                        context,
                        onTapConfirm: () async {
                          await Get.toNamed(
                            nav_routes.RoutesName.INVOICE_PRINT,
                            arguments: {'data': item, 'paid': paid},
                            preventDuplicates: false,
                          );
                          Get.back();
                        },
                        confirmText: 'چاپ',
                        type: ConfirmType.PRINT,
                        subtex: 'آیا از چاپ این فاکتور مطمئن هستید؟',
                      );
                    },
                  ),
                MiniBTN(
                  itemColor: darkMode.isTrue ? AppColors.grey : null,
                  icon: (!Platform.isAndroid && !Platform.isIOS)
                      ? IconsaxPlusLinear.copy
                      : IconsaxPlusLinear.share,
                  name: (!Platform.isAndroid && !Platform.isIOS)
                      ? 'کپی لینک'
                      : 'اشتراک‌ گذاری',
                  onTap: () async {
                    if (!Platform.isAndroid && !Platform.isIOS) {
                      await Clipboard.setData(
                        ClipboardData(text: 'onmik.ir/?${item.uid}'),
                      );
                      Alert.success(
                        'لینک فاکتور با موفقیت در کلیپ‌بورد کپی شد.',
                      );
                      return;
                    }
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            'سلام ${PersonFX.findByUID(item.personUID).name} عزیز\n${!item.type!.startsWith('pf') ? 'فاکتور' : 'پیش‌فاکتور'} شماره ${item.id} برای شما صادر شد.\nمشاهده ${!item.type!.startsWith('pf') ? 'فاکتور' : 'پیش‌فاکتور'}:\nonmik.ir/?${item.uid}\n${profile.getAt(0)?.name}',
                      ),
                    );
                  },
                ),

                // MiniBTN(
                //   icon: IconsaxPlusLinear.share,
                //   name: 'اشتراک فایل',
                //   onTap: () {
                //     //InvoicePDF.setting(item);
                //   },
                // ),
              ],
            )
          : null,
    );
  }
}
