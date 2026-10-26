// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/CatInput.dart';
import 'package:mik_components/elements/input/barcodeInput.dart';
import 'package:mik_components/elements/input/imageSelector.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/numInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/input/unitInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_pages/chatBase/addProduct/common/addGroupDetailsController.dart';
import 'package:mik_pages/chatBase/addProduct/common/additionalPrice.dart';
import 'package:mik_pages/chatBase/addProduct/common/detailsModel.dart';
import 'package:mik_pages/chatBase/addProduct/common/inventoryInput.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class ProductGroupDetailsScreen extends StatelessWidget {
  final List<String> products;
  ProductDB? productForEdit;

  ProductGroupDetailsScreen({super.key, required this.products, this.productForEdit});
  bool addOne = false;
  @override
  Widget build(BuildContext context) {
    //firstTime = products.isEmpty;
    final AddGroupDetailsController controller = Get.put(AddGroupDetailsController(products, productForEdit, firstTime: products.isEmpty));

    return Main(
      header: Header.page(
        context,
        text: productForEdit == null
            ? addOne
                  ? 'افزودن محصول'
                  : 'تکمیل جزئیات محصولات'
            : 'ویرایش ${productForEdit!.name}',
      ),
      forceSocket: controller.currentPage.value >= controller.products.length,
      initState: () async {
        if (products.length == 1 && products[0] == '') {
          addOne = true;
        }
        if (productForEdit != null) {
          controller.products[0].expandDetails.value = true;
        }
        return '';
      },
      child: (_) => Column(
        children: [
          if (!addOne && productForEdit == null) _buildSteps(context, controller),
          if (!addOne && productForEdit == null) const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (controller.currentPage.value >= controller.products.length && !addOne && productForEdit == null) {
                // Show summary screen
                return _buildSummaryScreen(context, controller);
              } else {
                // Show product forms
                return PageView.builder(
                  controller: controller.pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    controller.currentPage.value = index;
                  },
                  itemCount: controller.products.length,
                  itemBuilder: (context, index) {
                    return _buildProductForm(context, controller.currentPage.value, controller);
                  },
                );
              }
            }),
          ),
          if (!addOne && productForEdit == null)
            Obx(() {
              // Hide navigation buttons on summary screen
              if (controller.currentPage.value >= controller.products.length) {
                return const SizedBox.shrink();
              }
              return _buildNavigationButtons(controller);
            }),
          if (addOne || productForEdit != null)
            BTN(
              onTap: () async {
                if (controller.products[0].name == '') {
                  return Alert.error('نام محصول را وارد کنید.');
                } else if (controller.products[0].productType.value == '') {
                  return Alert.error('نوع محصول را انتخاب کنید.');
                } else if (controller.products[0].categoryUID.isEmpty) {
                  return Alert.error('دسته‌بندی محصول را انتخاب کنید.');
                } else if (controller.products[0].sellPrice.value == '' && productForEdit == null) {
                  return Alert.error('قیمت فروش محصول را وارد کنید.');
                } else {
                  if (productForEdit != null) {
                    await controller.editProduct();
                  } else {
                    await controller.saveProducts();
                  }
                }
              },
              name: productForEdit != null ? 'ویرایش محصول' : 'ثبت محصول',
            ),
        ],
      ),
    );
  }

  Widget _buildSteps(context, controller) {
    return (controller.currentPage.value >= controller.products.length)
        ? SizedBox.shrink()
        : Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.1), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                // Header with step counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => Text(
                        controller.products[controller.currentPage.value].name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                      child: Obx(
                        () => Text(
                          '${controller.currentPage.value + 1} از ${controller.products.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                Obx(() {
                  double step = ((controller.currentPage.value / controller.products.length) * 70) / 100;
                  double progress = step + 0.3;
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary), minHeight: 6),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress * 100).toInt()}% تکمیل شده',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
  }

  Widget _buildProductForm(BuildContext context, int index, AddGroupDetailsController controller) {
    ProductDetailsModel product = controller.products[index];
    product.nameController.text = product.name;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Input(
            controller: product.nameController,
            name: 'نام محصول',
            require: true,
            onChanged: (c) {
              if (addOne || productForEdit != null) controller.products[0].name = c;
            },
          ),
          if (productForEdit == null) const SizedBox(height: 20),
          // Form fields
          if (productForEdit == null) _buildProductTypeSelector(product),
          const SizedBox(height: 16),
          CatInput(
            type: 'product',
            require: true,
            selected: product.categoryUID,
            onChanged: (v) {
              product.categoryController.text = '';
              product.categoryUID.clear();
              v.forEach((e) {
                product.categoryController.text.isEmpty ? product.categoryController.text = e['name'] : product.categoryController.text = '${product.categoryController.text} ,${e['name']}';
                product.categoryUID.add(e['uid']);
              });
            },
            name: 'دسته بندی',
            controller: product.categoryController,
          ),
          if (productForEdit == null) const SizedBox(height: 16),
          if (productForEdit == null)
            PriceInput(
              controller: product.sellPriceController,
              name: 'قیمت فروش پیش‌فرض',
              require: true,
              onChanged: (v) {
                product.sellPrice.value = v;
              },
            ),

          if (productForEdit == null)
            Obx(() {
              return product.productType.value == 'کالا' && controller.firstTime
                  ? Column(
                      children: [
                        const SizedBox(height: 16),
                        PriceInput(controller: product.buyPriceController, name: 'قیمت خرید', require: true),
                      ],
                    )
                  : const SizedBox.shrink();
            }),

          if (productForEdit == null)
            Obx(() {
              return product.productType.value == 'کالا' && controller.firstTime
                  ? Column(
                      children: [
                        const SizedBox(height: 16),
                        Input(controller: product.stockController, name: 'موجودی', keyboardType: TextInputType.number, require: true),
                      ],
                    )
                  : const SizedBox.shrink();
            }),
          const SizedBox(height: 16),
          if (productForEdit == null)
            InkWell(
              onTap: () {
                product.expandDetails.toggle();
              },
              child: Container(
                alignment: Alignment.center,
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(width: 2, color: AppColors.grey.withValues(alpha: 0.8)),
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.grey.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    Text('اطلاعات اختیاری', style: Theme.of(context).textTheme.titleMedium),
                    Obx(
                      () => Transform.rotate(
                        angle: product.expandDetails.value ? 3.14159 : 0, // 180 degrees in radians
                        child: Icon(IconsaxPlusLinear.arrow_down),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Obx(() => AnimatedContainer(duration: Duration(milliseconds: 800), height: product.expandDetails.value ? null : 0, child: _buildOptionalFields(context, product))),
        ],
      ),
    );
  }

  Timer? _debounce;

  void onSearchChanged(String value, int page, int limit, Function(List<dynamic>? d, int? t) callback) {
    // حداقل طول سرچ (اختیاری)
    if (value.length < 2) return;

    // لغو debounce قبلی
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await getSearchDataTaxID(
        name: value,
        page: page,
        limit: limit,
        callback: (d, t) {
          callback(d, t); // کال‌بک اصلی اجرا میشه
        },
      );
    });
  }

  getSearchDataTaxID({required String name, required int page, required int limit, required callback}) async {
    Map<String, dynamic> query = {'name': name, 'page': page.toString(), 'limit': limit.toString()};
    var res = await API.searchProductTaxID(query);
    if (!res['hasError']) {
      if (res['data']['status']) {
        callback(res['data']['data']['content'], res['data']['data']['totalPages']);
      }
    }
  }

  normalizeName(String name) {
    List n = name.split('،');
    String one = '${n[0]} ${n[1]}-${n[2]}';
    return [one, ...n.sublist(3)];
  }

  Widget _buildOptionalFields(context, ProductDetailsModel product) {
    final controller = Get.find<AddGroupDetailsController>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: productForEdit == null ? 16.0 : 0, vertical: 8.0),
      child: Column(
        children: [
          if (productForEdit == null) MyDivider(text: 'قیمت‌گذاری'),
          if (productForEdit == null)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Row(
                children: [
                  Expanded(child: MyDivider(text: 'قیمت فروش پیش‌فرض', bold: false, endIndent: 5)),
                  Obx(() => Text(product.sellPrice.value)),
                ],
              ),
            ),
          if (productForEdit == null)
            Column(
              children: [
                for (int i = 0; i < product.additionalPrices.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Expanded(child: MyDivider(text: product.additionalPrices[i].nameController.text, bold: false, endIndent: 5)),
                        Text(product.additionalPrices[i].priceController.text),
                        IconButton(
                          icon: Icon(IconsaxPlusLinear.edit, color: AppColors.grey),
                          onPressed: () => controller.editAdditionalPrice(context, product, i),
                        ),
                        IconButton(
                          icon: Icon(IconsaxPlusLinear.trash_square, color: AppColors.error),
                          onPressed: () => controller.removeAdditionalPrice(product, i),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (productForEdit == null)
            BTN(
              onTap: () async {
                if (product.sellPrice.value == '') {
                  return Alert.error('ابتدا قیمت فروش پیش‌فرض را وارد کنید.');
                } else {
                  addNewPrice(context, product);
                }
              },
              name: 'افزودن قیمت فروش جدید',
              borderOnly: true,
            ),
          if (productForEdit == null) const SizedBox(height: 16),
          if (productForEdit == null) MyDivider(text: 'ویژگی‌ها و تنوع محصول'),
          if (productForEdit == null) _buildFeaturesSection(context, product, controller),
          Obx(
            () => UnitInput(
              selected: product.selectedUnit.value,
              onChanged: (value) {
                product.unitController.text = value['name'] ?? '';
                product.unitId = value['id'];
                product.selectedUnit.value = {'name': value['name'], 'id': value['id'].toString()};
              },
              controller: product.unitController,
              name: 'واحد اندازه‌گیری',
            ),
          ),
          const SizedBox(height: 16),
          NumberInput(
            controller: product.taxIDController,
            name: 'شناسه کالا',
            readOnly: true,
            onTap: () async {
              RxList sData = [].obs;
              RxInt page = 1.obs;
              RxInt limit = 20.obs;
              RxInt totalPage = 0.obs;
              final srch = TextEditingController(text: product.nameController.text);
              if (sData.isEmpty && product.nameController.text.length > 2) {
                await getSearchDataTaxID(
                  callback: (d, t) {
                    sData.value = d ?? [];
                    totalPage.value = t ?? 0;
                  },
                  name: product.nameController.text,
                  page: page.value,
                  limit: limit.value,
                );
              }
              MyBottomSheet.view(
                context,
                child: (d) => Column(
                  children: [
                    Input(
                      //type: SearchBarType.text,
                      controller: srch,
                      onChanged: (v) async {
                        srch.text = v;
                        if (v.length > 2) {
                          onSearchChanged(v, page.value, limit.value, (d, t) {
                            sData.value = d ?? [];
                            totalPage.value = t ?? 0;
                          });
                        }
                      },
                      name: 'نام محصول',
                    ),
                    Expanded(
                      child: Obx(
                        () => sData.isEmpty
                            ? EmptyList(text: 'کالا یا خدمتی با این نام یافت نشد.')
                            : ListView.builder(
                                controller: d,
                                itemCount: sData.value.length,
                                itemBuilder: (context, index) {
                                  return Obx(
                                    () => productTaxCard(sData[index], (t, id) {
                                      product.taxIDController.text = id.toString();
                                      Get.back();
                                    }),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
                initialChildSize: 0.6,
                title: 'شناسه کالا',
              );
            },
            suffixIcon: InkWell(
              onTap: () {
                MyBottomSheet.view(
                  context,
                  title: 'شناسه کالا',
                  child: (scrollController) => Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            Text(
                              'شناسه کالا و خدمات یک شماره ۱۳ رقمی است که به کالا یا خدمت تخصیص داده می‌شود و به ازای هر ردیف در صورت حساب الکترونیک توسط مودیان درج می‌شود.',
                              textAlign: TextAlign.justify,
                            ),
                            Text(
                              'درج شناسه کالا و خدمات در صورت حساب الکترونیک الزامی است و کلیه تولیدکنندگان، واردکنندگان و ارائه دهندگان کالا یا خدمات باید شناسه مذکور را از وزارت صمت دریافت کنند. همچنین تمامی مودیان می‌توانند جهت دریافت لیست شناسه کالا و خدمات موجود و وضعیت مشمولیت ارزش افزوده و ضرایب مالیاتی به سایت stuffid.tax.gov.ir مراجعه نمایند.',
                              textAlign: TextAlign.justify,
                            ),
                          ],
                        ),
                      ),
                      BTN(
                        onTap: () {
                          Get.back();
                        },
                        name: 'متوجه شدم',
                        color: AppColors.primary,
                        borderOnly: true,
                      ),
                    ],
                  ),
                );
              },
              child: Icon(IconsaxPlusLinear.message_question),
            ),
            onChanged: (v) {
              ///  if (addOne || productForEdit != null) controller.products[0].taxIDController.text = v;
            },
          ),
          const SizedBox(height: 16),
          Input(
            controller: product.taxController,
            name: 'مالیات ارزش افزوده',
            maxLength: 2,
            onChanged: (v) {
              if (int.tryParse(v) != null) {
                int val = int.parse(v);
                if (val > 70) {
                  Alert.warning('مقدار مالیات را صحیح وارد کنید.');
                  product.taxController.text = '';
                }
              }
            },
            suffixIcon: Icon(IconsaxPlusLinear.percentage_square),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Obx(
            () => product.isCommissionFixed.value || !product.isCommissionFixed.value
                ? Input(
                    keyboardType: TextInputType.number,
                    name: 'کمیسیون فروش',
                    controller: product.commissionAmountController,
                    onChanged: (value) {
                      try {
                        if (double.parse(value) > 50) {
                          product.isCommissionFixed.value = true;
                        } else {
                          product.isCommissionFixed.value = false;
                        }
                      } catch (e) {}
                    },
                    suffixIcon: InkWell(
                      onTap: () {
                        MyBottomSheet.view(
                          context,
                          title: 'کمیسیون فروش',
                          child: (scrollController) => Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Column(
                                  children: [
                                    Text('کمیسیون فروش می‌تواند به صورت درصدی یا مبلغ ثابت تعیین شود.', textAlign: TextAlign.justify),
                                    Text('اگر مقدار وارد شده کمتر و یا برابر 50 باشد، کمیسیون فروش بصورت درصدی از قیمت فروش در نظر گرفته می‌شود.', textAlign: TextAlign.justify),
                                    Text('و اگر مقدار وارد شده بیش از 50 باشد، به عنوان مبلغ ثابت (با واحد تومان) در نظر گرفته می‌شود.', textAlign: TextAlign.justify),
                                  ],
                                ),
                              ),
                              BTN(
                                onTap: () {
                                  Get.back();
                                },
                                name: 'متوجه شدم',
                                color: AppColors.primary,
                                borderOnly: true,
                              ),
                            ],
                          ),
                        );
                      },
                      child: Icon(IconsaxPlusLinear.message_question),
                    ),

                    // !product.isCommissionFixed.value && product.commissionPercentController.text.isEmpty ? Text('درصدی/ثابت', style: TextStyle(color: AppColors.grey, fontSize: 12)) : null,
                  )
                : SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          BarcodeInput(
            controller: product.barcodeController,
            onChanged: (v) {
              product.barcodeController.text = v;
            },
            name: 'بارکد',
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          MyDivider(text: 'تصاویر محصول'),
          ImageSelector(
            list: product.image,
            name: '',
            callback: (list) {
              product.image.value = list;
            },
            imgSelectName: RxList(),
            imgSelectBytes: RxList(),
          ),
        ],
      ),
    );
  }

  addNewPrice(context, ProductDetailsModel pr) {
    final priceCTL = TextEditingController();
    final nameCTL = TextEditingController();
    final dateCTL = TextEditingController();
    final priceF = FocusNode();
    final nameF = FocusNode();
    final dateF = FocusNode();
    // RxString def = 'خیر'.obs;

    priceF.requestFocus();

    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          PriceInput(focusNode: priceF, nextFocus: nameF, controller: priceCTL, name: 'قیمت', require: true),
          Input(focusNode: nameF, nextFocus: dateF, controller: nameCTL, name: 'نام قیمت', require: true),
          Row(
            children: [
              Flexible(
                flex: 3,
                child: BTN(
                  onTap: () async {
                    if (priceCTL.text == '') {
                      return Alert.error('قیمت را وارد کنید');
                    } else if (nameCTL.text == '' || nameCTL.text.length < 2) {
                      return Alert.error('نام قیمت را وارد کنید');
                    } else if (namePriceExist(pr, nameCTL.text)) {
                      return Alert.error('این نام برای این محصول قبلا تعریف شده است.');
                    } else if (priceExist(pr, Price.toInt(priceCTL.text))) {
                      return Alert.error('این قیمت برای این محصول قبلا تعریف شده است.');
                    }
                    String uid = ID.uidNew();
                    // ProductPriceDB p = ProductPriceDB(
                    //     uid: uid,
                    //     puid: '',
                    //     pro: op == null ? {} : op.pro,
                    //     price: Price.toInt(priceCTL.text),
                    //     name: nameCTL.text,
                    //     defaultPrice: false,
                    //     inserter: 0,
                    //     backup: op == null ? 'new' : 'edit');
                    pr.additionalPrices.add(AdditionalPrice(nameController: nameCTL, priceController: priceCTL));
                    Alert.success('قیمت با موفقیت ثبت شد.');
                    Get.back();
                  },
                  name: 'ثبت قیمت',
                ),
              ),
              Flexible(
                child: BTN(onTap: () => Get.back(), name: 'انصراف', borderOnly: true),
              ),
            ],
          ),
        ],
      ),
      isDismissible: false,
      title: 'افزودن قیمت جدید',
    );
  }

  bool priceExist(ProductDetailsModel pr, price) {
    if (Price.toInt(pr.sellPrice.value) == price) {
      return true;
    }
    if (pr.additionalPrices.isNotEmpty) {
      for (var i = 0; i < pr.additionalPrices.length; i++) {
        if (Price.toInt(pr.additionalPrices[i].priceController.text) == price) {
          return true;
        }
      }
    }
    return false;
  }

  bool namePriceExist(ProductDetailsModel pr, name) {
    if (pr.additionalPrices.isNotEmpty) {
      for (var i = 0; i < pr.additionalPrices.length; i++) {
        if (pr.additionalPrices[i].nameController.text == name) return true;
      }
    }
    return false;
  }

  Widget _buildFeaturesSection(BuildContext context, ProductDetailsModel product, AddGroupDetailsController controller) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          product.properties.isNotEmpty ? _buildVariantsTable(Get.context!, controller, product) : const SizedBox.shrink(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: BTN(
              onTap: () async {
                // _unfocusAll(Get.context!);
                // await Future.delayed(const Duration(milliseconds: 150));
                controller.showAddFeatureSheet(Get.context!, product);
              },
              name: 'افزودن/ویرایش ویژگی',
              borderOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsTable(BuildContext context, AddGroupDetailsController controller, ProductDetailsModel product) {
    // Generate variant combinations from properties
    List<List<Map>> variantCombinations = controller.getVariantCombinations(product);
    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 4,
              child: Text('تنوع', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (controller.firstTime)
              Expanded(
                flex: 3,
                child: Center(
                  child: Text('موجودی', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.centerLeft,
                child: Text('قیمت', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const Divider(),
        // Rows - iterate through variant combinations
        ...variantCombinations.asMap().entries.map((entry) {
          // int index = entry.key;

          List<Map> variantProperty = entry.value;
          final key = product.getVariantKey(variantProperty);

          // Create a controller for this variant's stock
          // We need to manage controllers to avoid recreating them on every rebuild if possible,
          // but for now, we'll create a new one and set its text.
          // Ideally, we should store these controllers in the model or controller,
          // but since we are moving away from a list of objects, we can just bind the value.
          // However, TextField needs a controller.
          // Let's use a local controller and initialize it.
          // To avoid cursor jumping, we might need a more persistent controller approach if this rebuilds often.
          // Given the current architecture, let's try initializing it with the current value.
          TextEditingController stockController = TextEditingController(text: product.variantStocks[key] ?? '0');
          stockController.selection = TextSelection.fromPosition(TextPosition(offset: stockController.text.length));

          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Variant Name - using ProductFX.productProNameWidget
                Expanded(flex: 5, child: ProductFX.productProNameWidget(variantProperty)),
                // Stock
                if (controller.firstTime)
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: InventoryInput(
                        controller: stockController,
                        name: '',
                        onChanged: (val) {
                          product.variantStocks[key] = val;
                        },
                      ),
                    ),
                  ),
                // Price - always show
                Expanded(
                  flex: 2,
                  child: Builder(
                    builder: (context) {
                      return Obx(() {
                        final isCustom = product.variantPrices.containsKey(key);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(isCustom ? 'سفارشی' : 'پیش‌فرض', style: TextStyle(fontSize: 10, color: isCustom ? AppColors.primary : Colors.grey)),
                            SizedBox(width: 4),
                            InkWell(
                              child: Icon(IconsaxPlusLinear.edit, size: 18, color: isCustom ? AppColors.primary : Colors.black),
                              onTap: () => _showVariantPriceSheet(context, controller, variantProperty, product),
                            ),
                          ],
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        // Stock summary footer
        if (product.stockController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Obx(() {
              int totalVariantStock = 0;
              // Sum values from variantStocks
              product.variantStocks.forEach((key, value) {
                totalVariantStock += int.tryParse(value) ?? 0;
              });

              int productStock = int.tryParse(product.stockController.text) ?? 0;
              bool isValid = totalVariantStock == productStock;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text('مجموع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text(
                        '$totalVariantStock از $productStock',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isValid ? Colors.green : Colors.red),
                      ),
                    ),
                  ),
                  Expanded(flex: 2, child: SizedBox()),
                ],
              );
            }),
          ),
      ],
    );
  }

  void _showVariantPriceSheet(BuildContext context, controller, List<Map> variantProperty, ProductDetailsModel product) {
    final key = product.getVariantKey(variantProperty);
    final currentPrices = product.variantPrices[key] ?? {};

    // Controllers for the sheet
    final mainPriceCtl = TextEditingController(text: currentPrices.containsKey('main') ? Price.showWithCurrency(currentPrices['main']!) : product.sellPriceController.text);

    final buyPriceCtl = TextEditingController(text: currentPrices.containsKey('buyPrice') ? Price.showWithCurrency(currentPrices['buyPrice']!) : product.buyPriceController.text);

    final Map<String, TextEditingController> additionalCtls = {};
    for (var price in product.additionalPrices) {
      additionalCtls[price.nameController.text] = TextEditingController(
        text: currentPrices.containsKey(price.nameController.text) ? Price.showWithCurrency(currentPrices[price.nameController.text]!) : price.priceController.text,
      );
    }

    MyBottomSheet.view(
      context,
      child: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            if (controller.firstTime)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: PriceInput(controller: buyPriceCtl, name: 'قیمت خرید'),
              ),
            PriceInput(controller: mainPriceCtl, name: 'قیمت فروش پایه'),
            for (var price in product.additionalPrices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: PriceInput(controller: additionalCtls[price.nameController.text]!, name: price.nameController.text),
              ),
            BTN(
              onTap: () {
                // Check if prices are custom (different from defaults)
                bool isCustom = false;
                final Map<String, int> newPrices = {};

                // Check main price
                if (Price.toInt(mainPriceCtl.text.toEnglishDigit()) != Price.toInt(product.sellPriceController.text.toEnglishDigit())) {
                  isCustom = true;
                }
                newPrices['main'] = Price.toInt(mainPriceCtl.text.toEnglishDigit());

                // Check buy price
                if (controller.firstTime) {
                  if (Price.toInt(buyPriceCtl.text.toEnglishDigit()) != Price.toInt(product.buyPriceController.text.toEnglishDigit())) {
                    isCustom = true;
                  }
                  newPrices['buyPrice'] = Price.toInt(buyPriceCtl.text.toEnglishDigit());
                }

                // Check additional prices
                for (var price in product.additionalPrices) {
                  final val = Price.toInt(additionalCtls[price.nameController.text]!.text.toEnglishDigit());
                  final defaultVal = Price.toInt(price.priceController.text.toEnglishDigit());

                  if (val != defaultVal) {
                    isCustom = true;
                  }
                  newPrices[price.nameController.text] = val;
                }

                if (isCustom) {
                  product.variantPrices[key] = newPrices;
                } else {
                  product.variantPrices.remove(key);
                }

                Get.back();
              },
              name: 'تایید',
            ),
          ],
        ),
      ),
      title: 'ویرایش قیمت تنوع',
    );
  }

  Widget _buildProductTypeSelector(ProductDetailsModel product) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        spacing: 5,
        children: [
          Flexible(child: MyDivider(text: 'نوع محصول', bold: false, require: true)),
          MyTab(
            tab: ['کالا', 'خدمت'],
            value: product.productType, // (product.productType.value == ProductType.product ? 'کالا' : 'خدمت').obs,
            width: false,
            widthSize: 60,
            callback: (value) {
              product.productType.value = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(AddGroupDetailsController controller) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: darkMode.value ? AppColors.backgroundDarkMode : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          // Previous button
          Obx(
            () => controller.currentPage.value > 0
                ? Expanded(
                    child: InkWell(
                      onTap: controller.previousPage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(IconsaxPlusLinear.arrow_right, size: 20, color: Colors.grey.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'قبلی',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),

          if (controller.currentPage.value > 0) const SizedBox(width: 12),

          // Skip button
          Expanded(
            child: InkWell(
              onTap: controller.skipCurrentProduct,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'رد شدن',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                    ),
                    const SizedBox(width: 8),
                    Icon(IconsaxPlusLinear.previous, size: 20, color: Colors.orange.shade700),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Next/Submit button
          Expanded(
            flex: controller.currentPage.value > 0 ? 1 : 2,
            child: Obx(() {
              bool isLast = controller.currentPage.value == controller.products.length - 1;
              return InkWell(
                onTap: controller.nextPage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? 'بررسی نهایی' : 'ذخیره و بعدی',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Icon(isLast ? IconsaxPlusLinear.tick_circle : IconsaxPlusLinear.arrow_left, size: 20, color: Colors.white),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScreen(BuildContext context, AddGroupDetailsController controller) {
    int completeCount = controller.productCompletionStatus.where((status) => status).length;
    int incompleteCount = controller.products.length - completeCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.1), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
            ),
            child: Column(
              children: [
                Icon(IconsaxPlusBold.tick_circle, size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text('خلاصه محصولات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$completeCount محصول کامل شده، $incompleteCount محصول ناقص', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Complete products
          if (completeCount > 0) ...[
            Row(
              children: [
                Icon(IconsaxPlusBold.tick_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('محصولات کامل شده ($completeCount)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(controller.products.length, (index) {
              if (!controller.productCompletionStatus[index]) {
                return const SizedBox.shrink();
              }
              final product = controller.products[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(IconsaxPlusLinear.tick_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // Incomplete products
          if (incompleteCount > 0) ...[
            Row(
              children: [
                Icon(IconsaxPlusBold.danger, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('محصولات ناقص ($incompleteCount)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(controller.products.length, (index) {
              if (controller.productCompletionStatus[index]) {
                return const SizedBox.shrink();
              }
              final product = controller.products[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(IconsaxPlusLinear.danger, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        controller.goToProduct(index);
                      },
                      child: const Text('تکمیل'),
                    ),
                    IconButton(
                      onPressed: () {
                        controller.removeProduct(index);
                      },
                      icon: Icon(IconsaxPlusLinear.trash_square, color: AppColors.error),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // Submit button
          Obx(() {
            bool allComplete = controller.productCompletionStatus.every((status) => status);
            return SizedBox(
              width: double.infinity,
              child: Opacity(
                opacity: allComplete ? 1.0 : 0.5,
                child: BTN(
                  onTap: allComplete
                      ? () async {
                          // Handle submission
                          await controller.saveProducts();
                        }
                      : () {
                          Alert.warning('لطفا ابتدا تمام محصولات را تکمیل کنید.');
                        },
                  name: controller.firstTime ? 'ثبت محصولات و فاکتور اول دوره' : 'ثبت محصولات',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

Widget productTaxCard(item, callback) {
  final parsed = parseProductName(item['name']);

  return InkWell(
    onTap: () => callback(parsed.title, item['id']),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// عنوان محصول
              Text(parsed.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

              const SizedBox(height: 8),

              /// ویژگی‌ها
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: parsed.features.map((f) {
                  return Chip(
                    label: Text(f, style: const TextStyle(fontSize: 10)),
                    side: BorderSide(width: 0.5),
                  );
                }).toList(),
              ),

              const SizedBox(height: 10),

              /// ID
              Align(
                alignment: Alignment.centerLeft,
                child: Text('شناسه مالیاتی کالا: ${item['id']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
        EndLine(rightPadding: 0),
      ],
    ),
  );
}

class ParsedProductName {
  final String title;
  final List features;

  ParsedProductName({required this.title, required this.features});
}

ParsedProductName parseProductName(String name) {
  final parts = name.split('،').map((e) => e.trim()).toList();

  final titleParts = parts.take(3).toList();
  final featureParts = parts.length > 3 ? parts.sublist(3) : [];

  return ParsedProductName(title: titleParts.join(' '), features: featureParts);
}
