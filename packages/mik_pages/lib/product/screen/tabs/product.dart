part of '../screen.dart';

class ProductTabDashboard extends StatefulWidget {
  final String appId;
  final ProductTabDashboardController? controller;
  const ProductTabDashboard({super.key, this.appId = 'mik', this.controller});

  @override
  State<ProductTabDashboard> createState() => _ProductTabDashboardState();
}

class _ProductTabDashboardState extends State<ProductTabDashboard> {
  late final c = widget.controller ?? productTabDashboardController;
  final _scroll = ScrollController();
  Worker? _readErrors;
  @override
  void initState() {
    super.initState();
    c.detach();
    _readErrors = everAll(
      [c.error, c.moreError, c.categoryError, c.brandError],
      (value) {
        if (mounted && value is String && value.isNotEmpty) {
          Alert.error(value, context: context);
        }
      },
    );
    _scroll.addListener(_loadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        c.attach(widget.appId, query: productDashboardController.search.value);
      }
    });
  }

  void _loadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 160) c.loadMore();
  }

  @override
  void dispose() {
    _readErrors?.dispose();
    c.detach();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.only(right: 10),
                child: const Text(
                  'محصولات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    onPressed: () => c.filter(context),
                    icon: const RotatedBox(
                      quarterTurns: 1,
                      child: Icon(IconsaxPlusLinear.setting_5),
                    ),
                  ),
                  Obx(
                    () => c.filtered.isTrue
                        ? Container(
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(top: 9, right: 7),
                            child: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              maxRadius: 5,
                            ),
                          )
                        : Container(),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: Obx(() {
              if (c.loading.isTrue) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.error.value != null) {
                return ErrorSection(c.error.value, act: c.init);
              }
              if (c.prd.isEmpty) {
                final narrowed =
                    c.filtered.isTrue ||
                    productDashboardController.search.value.trim().length >= 2;
                return EmptyList(
                  text: narrowed
                      ? 'محصولی با این مشخصات موجود نیست!'
                      : 'هیچ محصولی وجود ندارد!',
                  icon: narrowed
                      ? IconsaxPlusLinear.box_search
                      : IconsaxPlusLinear.box,
                );
              }
              return RefreshIndicator(
                onRefresh: c.init,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount:
                      c.prd.length +
                      (c.hasMore.isTrue || c.moreError.value != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == c.prd.length) {
                      return Obx(
                        () => Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: c.loadingMore.isTrue
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  children: [
                                    if (c.moreError.value != null)
                                      Text(c.moreError.value!),
                                    TextButton(
                                      onPressed: c.loadMore,
                                      child: Text(
                                        c.moreError.value == null
                                            ? 'نمایش بیشتر'
                                            : 'تلاش مجدد',
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }
                    final item = c.prd[index];
                    return PimProductItem(
                      item,
                      facts: c.facts,
                      onTap: () async {
                        await Get.toNamed(
                          RoutesName.PRODUCTDETAILS,
                          arguments: {
                            'appId': widget.appId,
                            'businessId': item.businessId,
                            'productId': item.id,
                          },
                        );
                        if (mounted) await c.init();
                      },
                      categories: c.categoryNames(item),
                      isLast: index == c.prd.length - 1 && c.hasMore.isFalse,
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
      Positioned(
        bottom: 7,
        right: 10,
        child: Obx(
          () => IgnorePointer(
            ignoring: !c.canCreate,
            child: MyMultiFAB(
              mainIcon: IconsaxPlusLinear.add,
              mainText: 'محصول جدید',
              items: [
                MultiFabItem(
                  icon: IconsaxPlusLinear.add,
                  text: 'افزودن تکی',
                  onTap: () async {
                    final contextSession = c.facts?.pim.context;
                    if (contextSession == null || !c.canCreate) return;
                    await Get.toNamed(
                      RoutesName.PRODUCTADD,
                      arguments: {
                        'appId': widget.appId,
                        'businessId':
                            contextSession.session.business.businessId,
                      },
                    );
                    if (mounted) await c.init();
                  },
                ),
                MultiFabItem(
                  icon: IconsaxPlusLinear.add,
                  text: 'افزودن گروهی',
                  onTap: () async {
                    final contextSession = c.facts?.pim.context;
                    if (contextSession == null || !c.canCreate) return;
                    await Get.toNamed(
                      nav_routes.RoutesName.PRODUCT_GROUP_ADD,
                      arguments: {'context': contextSession},
                      preventDuplicates: false,
                    );
                    if (mounted) await c.init();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
