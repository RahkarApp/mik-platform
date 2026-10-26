part of '../screen.dart';

class InvoiceCommission extends GetView {
  InvoiceDB item;
  InvoiceCommission(this.item, {super.key});
  @override
  Widget build(BuildContext context) {
    return item.commission!['amount'] > 0
        ? Column(
            children: [
              if (!item.type!.startsWith('pf') &&
                  item.commission!['milyar'] != 0 &&
                  item.type != 'buy')
                Container(
                  padding: const EdgeInsets.only(
                    right: 10,
                    left: 10,
                    bottom: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'وضعیت کمیسیون فاکتور',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            InvoiceFX.findMikyar(item.commission!['mikyar']) +
                                ': ',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            Price.show(item.commission!['amount']),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (!item.type!.startsWith('pf') &&
                  item.commission!['mikyar'] != 0 &&
                  item.type != 'buy')
                Obx(
                  () =>
                      invoiceDetailsScreenController.change.isFalse ||
                          invoiceDetailsScreenController.change.isTrue
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Flexible(
                                  child: BTN(
                                    name: commissionStatusName[i],
                                    color:
                                        commissionStatus[i] ==
                                            item.commission!['status']
                                        ? AppColors.success
                                        : Colors.grey,
                                    icon: InvoiceStatus.cIcon(
                                      commissionStatus[i],
                                    ),
                                    onTap: () {
                                      if (item.commission!['status'] == 0) {
                                        Confirm.con(
                                          context,
                                          subtex: item.commission != null
                                              ? '${commissionStatus[item.commission!['status']]} >>> ${commissionStatusName[i]}'
                                              : '',
                                          onTapConfirm: () {
                                            if (item.commission!['status'] !=
                                                commissionStatus[i]) {
                                              if (item.commission!['status'] ==
                                                  0) {
                                                // Alert.success(
                                                //     'تغییر وضیعت اعمال شد.');
                                                InvoiceFX.onClickCommissionStatus(
                                                  commissionStatus[i],
                                                  item,
                                                  (v) {
                                                    // invoiceDetailsScreenController
                                                    //     .init();
                                                  },
                                                );
                                              } else {
                                                Alert.error(
                                                  'وضعیت کمیسیون فاکتور قابل تغییر نیست.',
                                                );
                                              }
                                            } else {
                                              Alert.info('وضعیت کنونی کمیسیون');
                                            }
                                          },
                                          confirmText:
                                              'تغییر به ${commissionStatusName[i]}',
                                          type: ConfirmType.CHANGE,
                                        );
                                      } else {
                                        Alert.info(
                                          'وضعیت کمیسیون فاکتور قابل تغییر نیست.',
                                        );
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Container(),
                ),
            ],
          )
        : Container();
  }
}
