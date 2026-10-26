part of '../screen.dart';

RxList _cam = [].obs;

class CampainTabDashboard extends GetView {
  CampainTabDashboard({super.key});
  final scl = ScrollController();
  @override
  Widget build(BuildContext context) {
    init();
    return Scaffold(
      // floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      // floatingActionButton: MyFAB(
      //     icon: IconsaxPlusLinear.add,
      //     text: 'کمپین جدید',
      //     onTap: () async {
      //       // await ProductFX.addCat(callback: (v) {
      //       //   init();
      //       // });
      //       //  await Get.toNamed(RoutesName.PRODUCTCATADD);
      //     }),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.only(right: 10),
                child: const Text(
                  'لیست کمپین‌ها',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 45),
              // IconButton(
              //     onPressed: () {},
              //     icon: const RotatedBox(
              //         quarterTurns: 1, child: Icon(IconsaxPlusLinear.setting_5)))
            ],
          ),
          Expanded(
            child: [].isNotEmpty
                ? Obx(
                    () => _cam.isEmpty
                        ? EmptyList(
                            text: 'کمپینی با این مشخصات موجود نیست!',
                            icon: IconsaxPlusLinear.box_search,
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            controller: scl,
                            itemCount: _cam.length,
                            itemBuilder: (context, index) {
                              // return CategoryItem(
                              //   item: _cat[index],
                              //   index: index,
                              //   type: 'product',
                              //   callback: (v) {
                              //     init();
                              //   },
                              // );
                              return Container();
                            },
                          ),
                  )
                : EmptyList(
                    text: 'هیچ کمپینی وجود ندارد!',
                    desc: 'امکان ساخت کمپین بزودی فعال خواهد شد...',
                    icon: IconsaxPlusLinear.discount_circle,
                  ),
          ),
        ],
      ),
    );
  }

  init() {
    if (customerSearch.value.length >= 2) {
      _cam.value = category.values
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
                w.id
                        .toString()
                        .toEnglishDigit()
                        .replaceAll(' ', '')
                        .toLowerCase() ==
                    customerSearch.value
                        .toEnglishDigit()
                        .replaceAll(' ', '')
                        .toLowerCase(),
          )
          .toList();
    } else if (customerSearch.value.length < 2) {
      _cam.value = category.values.toList().toList();
    }
  }
}
