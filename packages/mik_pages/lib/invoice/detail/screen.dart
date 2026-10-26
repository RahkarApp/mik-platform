import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_variables/permissions.dart';
// ignore_for_file: prefer_typing_uninitialized_variables, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/disconnectSocket.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:mik_components/elements/productImage.dart';
import 'package:mik_consts/const.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/bill.dart';
import 'package:mik_data/utils/fx/branch.dart';
import 'package:mik_data/utils/fx/inserter.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/mikyar.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/fx/warehouse.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/cheque/components/form.dart';
import 'package:mik_pages/cheque/components/item.dart';
import 'package:mik_pages/invoice/detail/controller.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/private/invoiceStatus.dart';
import 'package:mik_utils/public/POS/pos.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:share_plus/share_plus.dart';
import 'package:text_scroll/text_scroll.dart';

import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mik_consts/colors.dart';

part './components/item.dart';
part './components/person.dart';
part './components/det.dart';
part 'components/btns/btns.dart';
part './components/desc.dart';
part './components/share.dart';
part './components/pf2f.dart';
part './components/acc.dart';
part './components/edit.dart';
part './components/bill.dart';
part './components/cheque.dart';
part './components/commission.dart';
part './components/btns/controller.dart';

RxBool statusChangeFactor = false.obs, changeFactor = false.obs;

InvoiceDetailsScreenController invoiceDetailsScreenController = Get.put(
  InvoiceDetailsScreenController(),
);

class InvoiceDetScreen extends GetView {
  InvoiceDB item;
  var type;

  InvoiceDetScreen({required this.item, this.type, super.key});

  @override
  Widget build(BuildContext context) {
    invoiceDetailsScreenController.type = type;
    invoiceDetailsScreenController.item = item;
    print(invoiceDetailsScreenController.item.uid);
    // invoiceDetailsScreenController.change.listen(
    //   (p0) {
    //     item = item;
    //   },
    // );

    return Main(
      initState: () async => {
        await Future.delayed(Duration(seconds: 1)),
        await invoiceDetailsScreenController.init(),
      },
      header: Header.page(
        context,
        text: invoiceDetailsScreenController.item.type == 'buy'
            ? 'جزئیات فاکتور خرید ${invoiceDetailsScreenController.item.id}'
            : (invoiceDetailsScreenController.item.type!.startsWith('pf'))
            ? 'جزئیات پیش‌فاکتور ${invoiceDetailsScreenController.item.id}'
            : 'جزئیات فاکتور فروش ${invoiceDetailsScreenController.item.id}',
      ),
      child: (d) {
        return Obx(
          () =>
              invoiceDetailsScreenController.change.isFalse ||
                  invoiceDetailsScreenController.change.isTrue
              ? SingleChildScrollView(
                  controller: invoiceDetailsScreenController.scrollCtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      InvoicePerson(invoiceDetailsScreenController.item),
                      Obx(
                        () =>
                            invoiceDetailsScreenController.change.isFalse ||
                                invoiceDetailsScreenController.change.isTrue
                            ? InvoiceItems(invoiceDetailsScreenController.item)
                            : InvoiceItems(invoiceDetailsScreenController.item),
                      ),
                      Obx(
                        () =>
                            invoiceDetailsScreenController.change.isFalse ||
                                invoiceDetailsScreenController.change.isTrue
                            ? InvoiceDetails(
                                item: invoiceDetailsScreenController.item,
                                bills:
                                    invoiceDetailsScreenController.bills.value,
                                paid:
                                    invoiceDetailsScreenController.paid ?? 0.0,
                              )
                            : Container(),
                      ),
                      InvoiceDesc(
                        invoiceDetailsScreenController.item.description ?? '',
                      ),
                      if (invoiceDetailsScreenController.item.type != 'buy' ||
                          (invoiceDetailsScreenController.item.type == 'buy' &&
                              invoiceDetailsScreenController.item.status!.every(
                                (t) => t['status'] != 444,
                              )))
                        InvoiceBTN(
                          item: invoiceDetailsScreenController.item,
                          paid: invoiceDetailsScreenController.paid ?? 0.0,
                        ),
                      if (invoiceDetailsScreenController.item.type != 'buy' ||
                          (invoiceDetailsScreenController.item.type == 'buy' &&
                              invoiceDetailsScreenController.item.status!.every(
                                (t) => t['status'] != 444,
                              )))
                        InvoiceShare(
                          item: invoiceDetailsScreenController.item!,
                          paid: invoiceDetailsScreenController.paid ?? 0.0,
                        ),

                      // if (!invoiceDetailsScreenController.item!.isBuy! || (invoiceDetailsScreenController.item!.isBuy! && invoiceDetailsScreenController.item!.status != 444))
                      //   InvoicePF2F(item),
                      Obx(
                        () => InvoiceAcc(
                          item: item,
                          paid: invoiceDetailsScreenController.paid ?? 0.0,
                          bills: invoiceDetailsScreenController.bills.value,
                        ),
                      ),
                      InvoiceEdit(
                        item: item,
                        paid: invoiceDetailsScreenController.paid ?? 0.0,
                      ),
                      Obx(
                        () => InvoiceBill(
                          item: item,
                          paid: invoiceDetailsScreenController.paid ?? 0.0,
                          bills: invoiceDetailsScreenController.bills.value,
                        ),
                      ),
                      Obx(
                        () => InvoiceCheque(
                          item: item,
                          chequeList:
                              invoiceDetailsScreenController.chequeList.value,
                        ),
                      ),
                      InvoiceCommission(invoiceDetailsScreenController.item!),
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              : Container(),
        );
      },
    );
  }
}
