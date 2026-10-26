part of '../screen.dart';

class InvoicePF2F extends GetView {
  InvoiceDB item;
  InvoicePF2F(this.item, {super.key});
  @override
  Widget build(BuildContext context) {
    return (item.type!.startsWith('pf') && item.status == 900)
        ? Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: BTN(
              color: AppColors.primary,
              icon: IconsaxPlusLinear.money_change,
              name: 'تبدیل به فاکتور',
              navigate: true,
              onTap: () async {
                await Get.toNamed(
                  RoutesName.INVOICEADD,
                  arguments: {
                    'type': 'convert',
                    'item': item,
                    'puid': item.personUID,
                    'isTabBar': false,
                    'isBack': true,
                  },
                );
                changeFactor.toggle();
              },
            ),
          )
        : Container();
  }
}
