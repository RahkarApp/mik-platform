import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/source/remote/api.dart';

class ProductImage {
  static img(context, item, double h, {showAll = false}) {
    File file =
        item.img != null &&
            (item.img!.isNotEmpty &&
                item.img![0] != '' &&
                item.img![0] != null &&
                item.img![0].length < 200)
        ? File('${prImageDir!.path}/${item.id}/${item.img?[0]}')
        : File('');
    // if (file.path == '')
    if (!file.existsSync() && item.img.isNotEmpty) {
      API.getIMG('product', item.id, item.img[0]);
      file =
          item.img != null &&
              (item.img!.isNotEmpty &&
                  item.img![0] != '' &&
                  item.img![0] != null &&
                  item.img![0].length < 200)
          ? File('${prImageDir!.path}/${item.id}/${item.img?[0]}')
          : File('');
    }
    return item.img != null &&
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
        : noimg(item.type, h);
  }

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
    // List<String> imageList = [];

    // for (var i = 0; i < item.img!.length; i++) {
    //   imageList.add('${prImageDir!.path}/${item.id}/${item.img?[i]}');
    // }
    getimg(path, i) async {
      if (!File(path).existsSync()) {
        await API.getIMG('product', item.id, item['img'][i]);
      }
      return '';
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
                          ) {
                            return FutureBuilder(
                              future: getimg(
                                '${prImageDir!.path}/${item.id}/${item.img?[itemIndex]}',
                                itemIndex,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                }
                                return Image.memory(
                                  File(
                                    '${prImageDir!.path}/${item.id}/${item.img?[itemIndex]}',
                                  ).readAsBytesSync(),
                                  width: Get.width * 0.9,
                                  height: Get.width * 0.9,
                                );
                              },
                            );
                          },
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
