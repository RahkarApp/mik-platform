part of '../screen.dart';

class InvoiceDesc extends GetView {
  String desc;
  InvoiceDesc(this.desc, {super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('توضیحات: ', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 5),
              Flexible(
                fit: FlexFit.tight,
                child: Text(desc, textAlign: TextAlign.justify),
              ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}
