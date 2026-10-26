part of '../../screen.dart';

class CustomerTabDashboardController extends GetxController {
  final ScrollController scl = ScrollController();
  RxList<PersonDB> prs = <PersonDB>[].obs;
  List<PersonDB> customer = <PersonDB>[];

  RxBool filtered = false.obs;

  RxString filterDebt = 'همه'.obs;
  RxString filterSort = ''.obs;
  filter(context) {
    MyBottomSheet.view(
      context,
      child: (d) => Column(
        children: [
          const Text(
            'فیلتر نمایش مشتریان',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          MyTab(
            width: Responsive.isMobile(context),
            widthSize: Responsive.isMobile(context) ? null : 200,
            tab: const ['همه', 'تسویه', 'بدهکاران'],
            value: filterDebt,
            callback: (v) {
              filterDebt.value = v;
              filtered.value = true;
              init();
            },
          ),
          MyDivider(),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            alignment: Alignment.topRight,
            child: const Text('مرتب سازی:'),
          ),
          MyTab(
            width: Responsive.isMobile(context),
            widthSize: Responsive.isMobile(context) ? null : 200,
            tab: const ['آخرین خرید', 'نام', 'بدهی'],
            value: filterSort,
            callback: (v) {
              filterSort.value = v;
              init();
            },
          ),
          const SizedBox(height: 30),
          Container(
            alignment: Alignment.bottomCenter,
            child: Row(
              children: [
                Flexible(
                  child: BTN(
                    borderOnly: true,
                    color: AppColors.backgroundDarkMode,
                    icon: null,
                    onTap: () {
                      Get.back();
                    },
                    navigate: true,
                    name: 'بستن',
                  ),
                ),
                Flexible(
                  child: BTN(
                    type: BTNType.cancel,
                    onTap: () {
                      filterDebt.value = 'همه';
                      filterSort.value = '';
                      filtered.value = false;
                      init();
                      Get.back();
                    },
                    name: 'حذف همه فیلتر‌ها',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // initialChildSize: 280,
      title: '',
    );
  }

  init() {
    customer = person.values.where((p) => p.isCustomer!).toList();
    if (customerSearch.value.length >= 2) {
      prs.value = customer
          .where(
            (w) =>
                w.name!
                    .replaceAll(' ', '')
                    .toLowerCase()
                    .toEnglishDigit()
                    .contains(
                      customerSearch.value
                          .replaceAll(' ', '')
                          .toLowerCase()
                          .toEnglishDigit(),
                    ) ||
                w.mobile
                            .toString()
                            .toEnglishDigit()
                            .replaceAll(' ', '')
                            .toLowerCase() ==
                        customerSearch.value
                            .toEnglishDigit()
                            .replaceAll(' ', '')
                            .toLowerCase() &&
                    (filterDebt.value == 'همه'
                        ? true
                        : filterDebt.value == 'تسویه'
                        ? AccountingFX.findPersonFinancial(w.uid!) == 0
                        : AccountingFX.findPersonFinancial(w.uid!) > 0),
          )
          .toList();
    } else if (customerSearch.value.length < 2) {
      prs.value = customer
          .where(
            (w) => (filterDebt.value == 'همه'
                ? true
                : filterDebt.value == 'تسویه'
                ? AccountingFX.findPersonFinancial(w.uid!) == 0
                : AccountingFX.findPersonFinancial(w.uid!) < 0),
          )
          .toList();
    }

    if (filterSort.value == 'آخرین خرید') {
      prs.sort(
        (a, b) =>
            DateTime.parse(
                  InvoiceFX.lastDate(b.uid!) ??
                      DateTime.now()
                          .add(const Duration(days: -36500))
                          .toIso8601String(),
                )
                .difference(
                  DateTime.parse(
                    InvoiceFX.lastDate(a.uid!) ??
                        DateTime.now()
                            .add(const Duration(days: -36500))
                            .toIso8601String(),
                  ),
                )
                .inDays,
      );
    } else if (filterSort.value == 'نام') {
      prs.sort((a, b) => b.name!.compareTo(a.org! ? a.orgName! : a.name!));
    } else if (filterSort.value == 'بدهی') {
      prs.sort(
        (a, b) =>
            AccountingFX.findPersonFinancial(a.uid!)
                .compareTo(AccountingFX.findPersonFinancial(b.uid!)),
      );
    }

    prs.assignAll(prs.reversed.toList());
  }
}
