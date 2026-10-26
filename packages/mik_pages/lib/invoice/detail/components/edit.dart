part of '../screen.dart';

class InvoiceEdit extends GetView {
  InvoiceDB item;
  double paid;
  InvoiceEdit({required this.item, required this.paid, super.key});
  @override
  Widget build(BuildContext context) {
    return (item.type == 'buy' ||
            (item.status!.any((t) => t['status'] != null && t['status'] < 3)) ||
            item.status == [])
        ? Stack(
            children: [
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.only(bottom: 10, right: 15, left: 15),
                child: Row(
                  children: [
                    if (((!(item.type == 'buy') && PermissionAccess.hasPermission(PermissionsName.invoicesSellEditAll)) ||
                            (!(item.type == 'buy') &&
                                PermissionAccess.hasPermission(PermissionsName.invoicesSellEdit) &&
                                item.inserter == mikyarProfileID)) ||
                        ((item.status == 900 && PermissionAccess.hasPermission(PermissionsName.invoicesPreEdit)) ||
                            (item.status == 900 &&
                                PermissionAccess.hasPermission(PermissionsName.invoicesPreEditAll) &&
                                item.inserter == mikyarProfileID)) ||
                        (((item.type == 'buy') && PermissionAccess.hasPermission(PermissionsName.invoicesBuyEdit)) ||
                            ((item.type == 'buy') &&
                                PermissionAccess.hasPermission(PermissionsName.invoicesBuyEditAll) &&
                                item.inserter == mikyarProfileID)))
                      MiniBTN(
                        // color: darkMode.isFalse ? AppColors.disable : null,
                        itemColor: darkMode.isTrue ? AppColors.grey : null,
                        icon: IconsaxPlusLinear.edit,
                        name: 'ویرایش فاکتور',
                        // navigate: true,
                        onTap: () async {
                          if (socketConnected.value == 'error' ||
                              socketConnected.value == 'disconnect') {
                            return Alert.warning(
                              'برای تغییر فاکتور باید به سرور متصل باشید.',
                            );
                          }
                          await Get.toNamed(
                            RoutesName.INVOICEADD,
                            arguments: {
                              'type': InvoiceFX.typeInvoice(item),
                              'item': item,
                              'isBack': true,
                            },
                          );
                        },
                      ),
                    if (item.type == 'buy')
                      if (PermissionAccess.hasPermission(PermissionsName.invoicesBuyDeleteAll) ||
                          (PermissionAccess.hasPermission(PermissionsName.invoicesBuyDelete) &&
                              item.inserter == mikyarProfileID))
                        MiniBTN(
                          // color: AppColors.error,
                          icon: IconsaxPlusLinear.trash,
                          itemColor: AppColors.error,
                          // type: BTNType.delete,
                          name: 'حذف فاکتور',
                          onTap: () async {
                            await InvoiceFX.deleteBuyInvoice(
                              context,
                              item,
                              paid,
                              false,
                              (v) {
                                if (v.runtimeType.toString() == 'bool') {
                                  Get.back();
                                }
                              },
                            );
                          },
                        ),
                  ],
                ),
              ),
              Obx(
                () =>
                    (socketConnected.value == 'error' ||
                        socketConnected.value == 'disconnect')
                    ? DisconnectSocket(tiny: true)
                    : Container(),
              ),
            ],
          )
        : Container();
  }
}
