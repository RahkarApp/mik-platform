// ignore_for_file: prefer_typing_uninitialized_variables

part of '../screen.dart';

class CostCheque extends GetView {
  CostDB item;
  List<ChequeDB> chequeList;
  var callback;
  CostCheque(
      {required this.item,
      required this.chequeList,
      required this.callback,
      super.key});
  @override
  Widget build(BuildContext context) {
    return chequeList.isNotEmpty
        ? Column(children: [
            Container(
                padding: const EdgeInsets.all(10),
                alignment: Alignment.centerRight,
                child: const Text(
                  'چک‌های هزینه',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                )),
            for (int i = 0; i < chequeList.length; i++)
              ChequeItem(
                  item: chequeList[i],
                  end: i + 1 == chequeList.length,
                  date: true,
                  callback: (v) => callback(v)
                  //   change.toggle();
                  ),
            MyDivider(),
          ])
        : Container();
  }
}
