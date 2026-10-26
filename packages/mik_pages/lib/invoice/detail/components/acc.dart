part of '../screen.dart';

class InvoiceAcc extends GetView {
  InvoiceDB item;
  double paid;
  List<BillDB> bills;
  InvoiceAcc({
    required this.item,
    required this.paid,
    required this.bills,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    int ex = 0;
    int dis = 0;
    for (var element in item.parameters!) {
      if (element['name'] == 'discount') {
        dis += int.tryParse(element['amount'].toString()) ?? 0;
      } else if (element['name'] == 'excess') {
        ex += int.tryParse(element['amount'].toString()) ?? 0;
      }
    }
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: Row(
            mainAxisAlignment: paid < (InvoiceFX.price(item) + ex - dis)
                ? MainAxisAlignment.spaceAround
                : MainAxisAlignment.center,
            children: [
              if (!item.type!.startsWith('pf') &&
                  (paid < (InvoiceFX.price(item) + ex - dis)))
                if ((item.type == 'buy' ||
                        item.status!.every(
                          (t) =>
                              t['status'] != null &&
                              (t['status'] <= 3 || t['status'] == 100),
                        )) &&
                    !item.type!.startsWith('pf') &&
                    (paid < (InvoiceFX.price(item) + ex - dis)))
                  MiniBTN(
                    icon: IconsaxPlusLinear.card,
                    name: item.type == 'buy' ? 'پرداخت وجه' : 'دریافت وجه',
                    onTap: () async {
                      await BillFX.addNewBillForItem(
                        context,
                        item.billUID!,
                        (v) {
                          invoiceDetailsScreenController.init();
                        },
                        paid,
                        item.type == 'buy' ? 'debt' : 'creadit',
                      );
                      // _addNewDebt(bills, item, (v) {
                      //   init();
                      // },
                      //  paid);
                    },
                  ),
              if ((item.type == 'buy' ||
                      item.status!.every(
                        (t) =>
                            t['status'] != null &&
                            (t['status'] <= 3 || t['status'] == 100),
                      )) &&
                  !item.type!.startsWith('pf') &&
                  (paid < (InvoiceFX.price(item) + ex - dis)))
                MiniBTN(
                  icon: IconsaxPlusLinear.money_4,
                  name: item.type == 'buy' ? 'پرداخت چک' : 'دریافت چک',
                  onTap: () async {
                    MyBottomSheet.view(
                      context,
                      child: (scrollController) => ChequeAddForm(
                        controller: scrollController,
                        type: item.type == 'buy' ? 'buy' : 'sell',
                        pname: PersonFX.findByUID(item.personUID).name,
                        pid: 0,
                        puid: item.personUID,
                        to: 'f${item.id}',
                        toUID: 'F-${item.uid}',
                        callback: (v) => {
                          invoiceDetailsScreenController.init(),
                        },
                      ),
                      // initialChildSize: 0.65,
                      title: item.type == 'buy' ? 'پرداخت چک' : 'دریافت چک',
                      //h: Get.height * 0.6
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
    );
  }
}
