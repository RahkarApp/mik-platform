part of '../screen.dart';

class InvoiceCheque extends GetView {
  InvoiceDB item;
  List<ChequeDB> chequeList;
  InvoiceCheque({required this.item, required this.chequeList, super.key});
  @override
  Widget build(BuildContext context) {
    return !item.type!.startsWith('pf') && chequeList.isNotEmpty
        ? Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                alignment: Alignment.centerRight,
                child: const Text(
                  'چک‌های فاکتور',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              for (int i = 0; i < chequeList.length; i++)
                ChequeItem(
                  item: chequeList[i],
                  end: i + 1 == chequeList.length,
                  date: true,
                  callback: (v) {
                    invoiceDetailsScreenController.init();
                  },
                ),
              MyDivider(),
            ],
          )
        : Container();
  }
}
