part of '../screen.dart';

class InvoicePerson extends GetView {
  InvoiceDB item;
  InvoicePerson(this.item, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                CircleAvatar(
                  maxRadius: 20,
                  backgroundColor: item.type == 'buy'
                      ? AppColors.blue
                      : InvoiceStatus.color(
                          InvoiceStatus.findLastStatusCode(item.status!),
                        ),
                  child: const Icon(
                    IconsaxPlusLinear.user,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    PersonFX.findByUID(item.personUID).name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.date.toString().toPersianDate()),
              Text(DateConvertor.showTime(DateTime.parse(item.date!))),
            ],
          ),
        ],
      ),
    );
  }
}
