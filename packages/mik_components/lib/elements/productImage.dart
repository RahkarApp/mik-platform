import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/models/pim_product.dart';
import 'package:mik_data/source/remote/models/pim_media.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/product_media.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_variables/variable.dart';

class ProductImage {
  static img(
    context,
    item,
    double h, {
    showAll = false,
    BusinessContext? business,
  }) {
    if (item is PimProduct) {
      return remote(context, item, h, showAll: showAll, business: business);
    }
    File file =
        item.img != null &&
            (item.img!.isNotEmpty &&
                item.img![0] != '' &&
                item.img![0] != null &&
                item.img![0].length < 200)
        ? File('${prImageDir!.path}/${item.id}/${item.img?[0]}')
        : File('');

    return Container(
      width: h,
      height: h,
      alignment: Alignment.center,
      child: Stack(
        children: [
          item.img != null &&
                  (item.img!.isNotEmpty &&
                      item.img![0] != '' &&
                      item.img![0] != null &&
                      item.img![0].length < 200)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: file.existsSync()
                      ? InkWell(
                          onTap: () {
                            if (item.img!.isNotEmpty && showAll) {
                              showAllImg(context, item);
                            }
                          },
                          child: Image.memory(
                            file.readAsBytesSync(),
                            width: 70,
                            height: 70,
                            errorBuilder: (context, error, stackTrace) {
                              return noimg(item.type, h);
                            },
                          ),
                        )
                      : noimg(item.type, h),
                )
              : noimg(item.type, h),
          if (item.archive ?? false) archived(),
        ],
      ),
    );
  }

  static Widget remote(
    BuildContext context,
    PimProduct item,
    double h, {
    BusinessContext? business,
    List<PimMedia>? media,
    bool showAll = false,
  }) {
    final rows = [...(media ?? item.media)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return SizedBox(
      width: h,
      height: h,
      child: Stack(
        children: [
          if (rows.isEmpty)
            noimg('product', h)
          else
            _RemoteProductImage(
              product: item,
              media: rows,
              size: h,
              business: business,
              showAll: showAll,
            ),
          if (item.status == 'ARCHIVED') archived(),
        ],
      ),
    );
  }

  static Widget archived() => RotatedBox(
    quarterTurns: 1,
    child: Container(
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.error, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      height: 25,
      child: Text(
        'آرشیو',
        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
      ),
    ),
  );

  static noimg(type, double h) {
    return Container(
      width: h,
      height: h,
      decoration: h == 70
          ? BoxDecoration(
              color: AppColors.boxBackground.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(5),
            )
          : null,
      child: Icon(
        (type == 'product') ? IconsaxPlusLinear.box : IconsaxPlusLinear.tag_2,
        size: 40,
        color: Colors.grey.withValues(alpha: 0.5),
      ),
    );
  }

  static showAllImg(context, item, {name = false}) {
    RxString select = '${prImageDir!.path}/${item.id}/${item.img![0]}'.obs;
    List<String> imageList = [];

    for (var i = 0; i < item.img!.length; i++) {
      imageList.add('${prImageDir!.path}/${item.id}/${item.img?[i]}');
    }
    MyBottomSheet.view(
      context,
      child: (ScrollController scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(
            () => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: File(select.value).existsSync()
                  ? CarouselSlider.builder(
                      itemCount: item.img.length,
                      itemBuilder:
                          (
                            BuildContext context,
                            int itemIndex,
                            int pageViewIndex,
                          ) => Image.memory(
                            File(
                              '${prImageDir!.path}/${item.id}/${item.img?[itemIndex]}',
                            ).readAsBytesSync(),
                            width: Get.width * 0.9,
                            height: Get.width * 0.9,
                          ),
                      options: CarouselOptions(
                        height: 400,
                        // aspectRatio: 1 / 1,
                        viewportFraction: 0.8,
                        initialPage: 0,
                        enableInfiniteScroll: true,
                        reverse: false,
                        autoPlay: true,
                        autoPlayInterval: Duration(seconds: 3),
                        autoPlayAnimationDuration: Duration(milliseconds: 1200),
                        autoPlayCurve: Curves.fastOutSlowIn,
                        enlargeCenterPage: true,
                        enlargeFactor: 0.3,
                        onPageChanged: (i, c) {},
                        scrollDirection: Axis.horizontal,
                      ),
                    )
                  : SizedBox(
                      width: 80,
                      height: 80,
                      child: Icon(
                        item.type == null ||
                                (item.type != null && item.type == 'product')
                            ? IconsaxPlusLinear.box
                            : IconsaxPlusLinear.tag_2,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
        ],
      ),
      title: name ? item.name : '',
      // h: 450,
    );
  }
}

class _RemoteProductImage extends StatefulWidget {
  final PimProduct product;
  final List<PimMedia> media;
  final double size;
  final BusinessContext? business;
  final bool showAll;
  const _RemoteProductImage({
    required this.product,
    required this.media,
    required this.size,
    this.business,
    required this.showAll,
  });
  @override
  State<_RemoteProductImage> createState() => _RemoteProductImageState();
}

class _RemoteProductImageController extends GetxController {
  String? url, error;
  int generation = 0;
  bool reported = false;
  ProductMediaFX? fx;
}

class _RemoteProductImageState extends State<_RemoteProductImage> {
  late final _page = _RemoteProductImageController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(_RemoteProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.first.mediaId != widget.media.first.mediaId ||
        oldWidget.product.id != widget.product.id ||
        oldWidget.product.revision != widget.product.revision ||
        !identical(oldWidget.business, widget.business)) {
      load();
    }
  }

  Future<void> load({bool reload = false}) async {
    final request = ++_page.generation;
    _page.url = _page.error = null;
    _page.reported = false;
    try {
      final business = widget.business;
      if (business == null ||
          business.session.business.businessId != widget.product.businessId) {
        throw StateError('نشست محصول در دسترس نیست.');
      }
      _page.fx = ProductMediaFX.forContext(business);
      final result = await _page.fx!.url(
        widget.product.id,
        widget.media.first.mediaId,
        reload: reload,
      );
      if (mounted && _page.generation == request) {
        _page.url = result;
        _page.update();
      }
    } catch (failure) {
      if (!mounted || request != _page.generation) return;
      {
        _page.error = ProductMediaFX.message(failure);
        _page.update();
      }
      notice();
    }
  }

  void notice() {
    if (_page.reported) return;
    _page.reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Alert.error(
          _page.error ?? 'نمایش عکس انجام نشد؛ برای تلاش مجدد روی آن بزنید.',
          context: context,
        );
      }
    });
  }

  Future<void> gallery() async {
    if (!widget.showAll || _page.fx == null) return;
    try {
      final urls = await Future.wait(
        widget.media.map((m) => _page.fx!.url(widget.product.id, m.mediaId)),
      );
      if (!mounted) return;
      await MyBottomSheet.view(
        context,
        title: widget.product.name,
        child: (_) => CarouselSlider.builder(
          itemCount: urls.length,
          itemBuilder: (_, index, page) => Image.network(
            urls[index],
            fit: BoxFit.contain,
            semanticLabel: widget.media[index].alt ?? widget.product.name,
            errorBuilder: (_, failure, stack) => InkWell(
              onTap: () =>
                  Alert.error('نمایش عکس انجام نشد.', context: context),
              child: ProductImage.noimg('product', 90),
            ),
          ),
          options: CarouselOptions(
            height: MediaQuery.sizeOf(context).height * .5,
            enableInfiniteScroll: urls.length > 1,
            viewportFraction: .9,
          ),
        ),
      );
    } catch (failure) {
      if (mounted) {
        Alert.error(ProductMediaFX.message(failure), context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_RemoteProductImageController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        if (_page.error != null) {
          return Tooltip(
            message: _page.error!,
            child: InkWell(
              onTap: () => load(reload: true),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: const Icon(IconsaxPlusLinear.refresh),
              ),
            ),
          );
        }
        if (_page.url == null) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return InkWell(
          onTap: gallery,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(
              _page.url!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              semanticLabel: widget.media.first.alt ?? widget.product.name,
              errorBuilder: (_, failure, stack) {
                notice();
                return InkWell(
                  onTap: () {
                    {
                      _page.update();
                    }
                    load(reload: true);
                  },
                  child: ProductImage.noimg('product', widget.size),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
