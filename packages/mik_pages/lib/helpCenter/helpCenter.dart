import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/asyncWidget.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/helpCenterAPI.dart';
import 'package:mik_pages/helpCenter/components/blockRenderer.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:widget_loading/widget_loading.dart';


class HelpPage extends GetView {
  HelpPage({super.key});
  List helpList = [];
  RxList showList = [].obs;
  RxBool loading = false.obs;
  RxList<Map<String, dynamic>> cat = <Map<String, dynamic>>[
    {"title": "همه", "id": null},
  ].obs;
  RxString catSelected = '-'.obs;
  Timer? searchTimer;
  final srch = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => {await getList()},
      loadingDuration: 1500,
      header: Header.page(context, text: 'مرکز آموزش', help: false),
      child: (data) => Obx(
        () => Column(
          children: [
            SizedBox(height: 10),
            MySearchBar(
              controller: srch,
              type: SearchBarType.text,
              callback: (v) {
                try {
                  searchTimer!.cancel();
                } catch (e) {}
                searchTimer = Timer(Duration(milliseconds: 200), () async {
                  if (v.length > 2) {
                    await getPosts(search: v);
                  } else {
                    await getPosts();
                  }
                });
              },
            ),
            SizedBox(
              height: 25,
              child: ListView.builder(
                itemCount: cat.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 5, left: 5),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        catSelected.value = cat[index]['id'] ?? '-';
                        loading.value = true;
                        await getPosts(p: 1.toString(), catid: cat[index]['id']);
                        loading.value = false;
                      },
                      child: Obx(
                        () => Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            border: catSelected.value != (cat[index]['id'] ?? '-') ? Border.all(color: darkMode.value ? Colors.white : AppColors.primary, width: 1) : null,
                            color: catSelected.value == (cat[index]['id'] ?? '-') ? AppColors.primary : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(cat[index]['title']!, style: TextStyle(color: catSelected.value == (cat[index]['id'] ?? '-') || darkMode.value ? Colors.white : AppColors.primary)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: loading.value
                  ? CircularWidgetLoading(
                      dotRadius: 2,
                      maxLoadingCircleSize: 30,
                      loadingDuration: Duration(milliseconds: 1000),
                      appearingDuration: const Duration(milliseconds: 500),
                      dotColor: AppColors.primary,
                      child: Container(),
                    )
                  : showList.isNotEmpty
                  ? Obx(
                      () => GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        padding: const EdgeInsets.all(5),
                        children: List<Widget>.from(showList.map((post) => item(post: post)).toList()),
                      ),
                    )
                  : EmptyList(text: 'آموزشی یافت نشد.', icon: IconsaxPlusLinear.teacher),
            ),

            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: hasPrevPage
                        ? () async {
                            loading.value = true;
                            page.value--;
                            await getPosts(catid: catSelected.value, p: page.value.toString());
                            loading.value = false;
                          }
                        : null,
                    icon: Icon(
                      IconsaxPlusLinear.arrow_square_right,
                      size: 30,
                      color: !hasPrevPage
                          ? darkMode.value
                                ? Colors.white24
                                : Colors.black26
                          : null,
                    ),
                  ),
                  Flexible(
                    child: Row(
                      children: [
                        ...getVisiblePages(currentPage: page.value, totalPages: totalPages).map((i) {
                          return Flexible(
                            child: InkWell(
                              onTap: () async {
                                loading.value = true;
                                page.value = i;
                                await getPosts(catid: catSelected.value, p: page.value.toString());
                                loading.value = false;
                              },
                              child: Obx(
                                () => Container(
                                  height: 27,
                                  constraints: BoxConstraints(minWidth: 27),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: i == page.value ? AppColors.primary.withValues(alpha: 0.5) : null,
                                    border: Border.all(
                                      width: 1.5,
                                      color: i == page.value
                                          ? AppColors.primary.withValues(alpha: 0.5)
                                          : darkMode.value
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  margin: EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    (i).toString(),
                                    style: i == page.value ? TextStyle(color: Colors.white, fontWeight: FontWeight.bold) : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: hasNextPage
                        ? () async {
                            loading.value = true;
                            page.value++;
                            await getPosts(catid: catSelected.value, p: page.value.toString());
                            loading.value = false;
                          }
                        : null,
                    icon: Icon(
                      IconsaxPlusLinear.arrow_square_left,
                      size: 30,
                      color: !hasNextPage
                          ? darkMode.value
                                ? Colors.white24
                                : Colors.black26
                          : null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  int totalDocs = 0, limit = 10, totalPages = 0;
  RxInt page = 1.obs;
  bool hasPrevPage = false, hasNextPage = false;
  getList() async {
    //  دریافت دسته‌بندی‌ها
    var catdata = await HelpCenterAPI.getCat();
    if (catdata['hasError']) {
      Alert.error(catdata['message']);
    } else {
      cat.value.clear();
      cat.add({"title": "همه", "id": null});
      catdata['data']['docs'].reversed.toList();
      List<Map<String, dynamic>> catGet = [];
      catdata['data']['docs'].forEach((e) => catGet.add(e));
      catGet = catGet.reversed.toList();
      cat.addAll(catGet);
    }
    await getPosts();
    return '';
  }

  getPosts({p, catid, search}) async {
    // دریافت لیست پست‌ها
    var res = await HelpCenterAPI.getHelpList(page: p, cat: catid == '-' ? null : catid, search: search);
    if (res['hasError']) {
      Alert.error(res['message']);
    } else {
      showList.value = [];
      totalDocs = res['data']["totalDocs"];
      limit = res['data']["limit"];
      totalPages = res['data']["totalPages"];
      page.value = res['data']["page"];
      hasPrevPage = res['data']["hasPrevPage"];
      hasNextPage = res['data']["hasNextPage"];
      helpList = List<HelpPost>.from(res['data']['docs'].map((json) => HelpPost.fromJson(json)));
      showList.value = helpList;
    }
  }

  item({required HelpPost post}) {
    String catName = '';
    if (cat.isNotEmpty && post.categories != '') {
      try {
        catName = cat.firstWhere((e) => e['id'] == post.categories)['title']; //firstWhere((element) => post.categories.contains(element['id']), orElse: () => {"title": ""})['title'];
      } catch (e) {}
    }

    return Container(
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Material(
        elevation: 2,
        color: darkMode.isFalse ? Colors.grey.shade100 : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Get.toNamed(RoutesName.DRAWER_HELP_DETAIL, arguments: {'id': post.id, 'name': post.title});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                    child: Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: AsyncWidget(
                        loadingDuration: 1000,
                        child: (d) {
                          return d == null || d == ''
                              ? Image.asset('assets/images/logo/logow.png', color: AppColors.primary)
                              : CachedNetworkImage(imageUrl: d!, cacheKey: post.heroImage, fit: BoxFit.cover, width: 200);
                        },
                        initState: () => getMediaUrl(post.heroImage),
                      ),
                    ),
                  ),
                  Obx(
                    () => catSelected.value != post.categories && catName.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.only(right: 5, top: 5),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              //border: Border.all(color: AppColors.primary, width: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(catName, style: TextStyle(fontSize: 10, color: Colors.white)),
                          )
                        : SizedBox.shrink(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(post.desc, maxLines: 3, style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, textAlign: TextAlign.justify),
                    SizedBox(height: 5),
                    Container(
                      alignment: Alignment.bottomLeft,
                      child: Text(post.date.toPersianDate(), style: TextStyle(fontSize: 11, color: darkMode.value ? Colors.white54 : Colors.black54)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<int> getVisiblePages({required int currentPage, required int totalPages, int maxVisible = 6}) {
  // محافظ مطلق
  if (totalPages <= 0) return [];

  // اگر کل صفحات کم است
  if (totalPages <= maxVisible) {
    return List<int>.generate(totalPages, (i) => i + 1);
  }

  int start = currentPage - 2;

  // clamp start
  if (start < 1) {
    start = 1;
  }

  // اگر از انتها زد بیرون
  if (start + maxVisible - 1 > totalPages) {
    start = totalPages - maxVisible + 1;
  }

  // 🔒 این خط کل ماجراست
  return List<int>.generate(maxVisible, (i) => start + i).where((p) => p >= 1 && p <= totalPages).toList();
}

class HelpPost {
  final String id;
  final String title;
  final String heroImage;
  final String categories;
  final String date;
  final String desc;

  HelpPost({required this.id, required this.title, required this.heroImage, required this.categories, required this.date, required this.desc});

  factory HelpPost.fromJson(Map<String, dynamic> json) {
    return HelpPost(id: json['id'], title: json['title'], heroImage: json['heroImage'] ?? '', categories: json['categories'] ?? '', date: json['createdAt'], desc: json['meta']['description'] ?? '');
  }
}
