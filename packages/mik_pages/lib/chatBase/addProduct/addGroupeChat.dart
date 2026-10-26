import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_pages/chatBase/common/chatMessageModel.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/pim_group.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:glass/glass.dart';

import '../../product/bulk/controller.dart';

class ProductGroupAddController extends GetxController {
  final ProductBulkController bulk;
  ProductGroupAddController(this.bulk) {
    inputController.addListener(
      () => hasInputText.value = inputController.text.isNotEmpty,
    );
  }
  final products = <String>[].obs;
  final chatMessages = <ChatMessage>[].obs;
  final inputController = TextEditingController();
  final fc = FocusNode(), scrollController = ScrollController();
  final hasInputText = false.obs,
      isEditingMode = false.obs,
      hasPendingProducts = false.obs,
      showInputArea = true.obs,
      busy = false.obs;
  String? editingProductName, editingId, previousInputText;

  Future<void> load() async {
    await bulk.load();
    if (bulk.loadError.value != null) throw StateError(bulk.loadError.value!);
    if (!bulk.locked) {
      // The chat collects names first; discard only the untouched blank form row.
      bulk.rows.removeWhere(
        (r) =>
            r.name.isEmpty &&
            r.price.isEmpty &&
            r.categoryIds.isEmpty &&
            r.unitId == null &&
            r.brandId == null,
      );
    }
    refreshMessages();
  }

  void refreshMessages() {
    products.assignAll(bulk.rows.map((r) => r.name));
    chatMessages.clear();
    hasPendingProducts.value = products.isNotEmpty;
    showInputArea.value = products.isEmpty && !bulk.locked;
    if (products.isEmpty) {
      chatMessages.add(
        ChatMessage(
          text: bulk.locked
              ? 'درخواست باز مربوط به عملیات دیگری است؛ آن را در صفحه مربوط ادامه دهید.'
              : 'سلام! 👋\n\nنام محصولاتی که میخوای اضافه کنی رو یکی یکی برام بفرست.\nوقتی تموم کردی، روی دکمه "تکمیل اطلاعات و ثبت" بزن.',
          isUser: false,
          isSystemMessage: true,
          isWelcomeMessage: true,
        ),
      );
    } else {
      for (final row in bulk.rows) {
        chatMessages.add(
          ChatMessage(text: row.name, isUser: true, uuid: row.id),
        );
        chatMessages.add(
          ChatMessage(
            text: bulk.locked
                ? bulk.progress(row)
                : '✅ "${row.name}" به پیش‌نویس اضافه شد',
            isUser: false,
            isSystemMessage: true,
          ),
        );
      }
      chatMessages.add(
        ChatMessage(
          text: bulk.locked
              ? 'ثبت قبلی کامل نشده است؛ برای جلوگیری از ثبت تکراری همان درخواست‌ها را ادامه دهید.'
              : 'محصولاتی که قبلا اضافه کرده بودی هنوز تایید نهایی نشدن\nمیخوای ادامه بدی یا همه رو حذف میکنی؟',
          isUser: false,
          isSystemMessage: bulk.locked,
          isPendingConfirmation: !bulk.locked,
        ),
      );
    }
    gotoEndScroll();
  }

  void gotoEndScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String normalize(String value) => value
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase()
      .toEnglishDigit();
  bool duplicate(String value, {String? exceptId}) => bulk.rows.any(
    (r) => r.id != exceptId && normalize(r.name) == normalize(value),
  );
  Future<void> addProduct(String value) async {
    if (busy.value || bulk.locked || hasPendingProducts.value) return;
    value = value.trim();
    if (value.isEmpty) return;
    if (value.length > 200 ||
        RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]').hasMatch(value)) {
      chatMessages.add(
        ChatMessage(
          text: 'نام محصول باید حداکثر ۲۰۰ نویسه و معتبر باشد.',
          isUser: false,
          isSystemMessage: true,
        ),
      );
      gotoEndScroll();
      return;
    }
    if (duplicate(value, exceptId: editingId)) {
      chatMessages.add(
        ChatMessage(
          text: '❌ "$value" قبلاً اضافه شده است',
          isUser: false,
          isDuplicate: true,
          isSystemMessage: true,
        ),
      );
      gotoEndScroll();
      return;
    }
    busy.value = true;
    try {
      if (editingId != null) {
        final row = bulk.rows.where((r) => r.id == editingId).firstOrNull;
        if (row == null) return;
        final old = row.name;
        row.name = value;
        for (final message in chatMessages.where(
          (m) => m.isUser && m.uuid == row.id,
        )) {
          message.text = value;
        }
        chatMessages.add(
          ChatMessage(
            text: '✏️ "$old" به "$value" ویرایش شد',
            isUser: false,
            isSystemMessage: true,
          ),
        );
      } else {
        final row = BulkProductRow(name: value);
        bulk.rows.add(row);
        chatMessages.add(ChatMessage(text: value, isUser: true, uuid: row.id));
        chatMessages.add(
          ChatMessage(
            text: '✅ "$value" به پیش‌نویس اضافه شد',
            isUser: false,
            isSystemMessage: true,
          ),
        );
      }
      await bulk.persist();
      products.assignAll(bulk.rows.map((r) => r.name));
      inputController.text = editingId == null ? '' : previousInputText ?? '';
      editingProductName = null;
      editingId = null;
      previousInputText = null;
      isEditingMode.value = false;
      chatMessages.refresh();
      gotoEndScroll();
    } finally {
      busy.value = false;
    }
  }

  Future<void> removeProductByName(String name, {String? rowId}) async {
    if (busy.value || bulk.locked) return;
    busy.value = true;
    try {
      final row = bulk.rows
          .where((r) => rowId == null ? r.name == name : r.id == rowId)
          .firstOrNull;
      if (row == null) return;
      bulk.rows.remove(row);
      await bulk.persist();
      products.assignAll(bulk.rows.map((r) => r.name));
      chatMessages.removeWhere(
        (m) => m.uuid == row.id || !m.isUser && m.text.contains('"$name"'),
      );
      gotoEndScroll();
    } finally {
      busy.value = false;
    }
  }

  void clearAllProducts() {
    if (busy.value || bulk.locked) return;
    chatMessages.removeWhere((m) => m.isPendingConfirmation);
    chatMessages.add(
      ChatMessage(
        text: 'آیا مطمئن هستید که می‌خواهید تمام محصولات را حذف کنید؟',
        isUser: false,
        isDeleteAllConfirmation: true,
      ),
    );
    gotoEndScroll();
  }

  Future<void> confirmDeleteAll() async {
    if (busy.value || bulk.locked) return;
    busy.value = true;
    try {
      bulk.rows.clear();
      await bulk.persist();
      inputController.clear();
      refreshMessages();
    } finally {
      busy.value = false;
    }
  }

  void cancelDeleteAll() {
    refreshMessages();
  }

  void confirmPendingProducts() {
    if (busy.value || bulk.locked) return;
    hasPendingProducts.value = false;
    showInputArea.value = true;
    chatMessages.removeWhere((m) => m.isPendingConfirmation);
    chatMessages.add(
      ChatMessage(
        text: '✅ خوب! محصولات جدیدت رو اضافه کن',
        isUser: false,
        isSystemMessage: true,
      ),
    );
    gotoEndScroll();
  }

  @override
  void onClose() {
    inputController.dispose();
    fc.dispose();
    scrollController.dispose();
    bulk.onClose();
    super.onClose();
  }
}

class ProductGroupAddScreen extends StatefulWidget {
  final BusinessContext context;
  final ProductBulkController? controller;
  const ProductGroupAddScreen({
    super.key,
    required this.context,
    this.controller,
  });
  @override
  State<ProductGroupAddScreen> createState() => _ProductGroupAddScreenState();
}

class _ProductGroupAddScreenState extends State<ProductGroupAddScreen> {
  late final controller = ProductGroupAddController(
    widget.controller ??
        ProductBulkController(
          PimGroupFX.forProducts(PimFX.forContext(widget.context)),
        ),
  );
  Future<void> complete() async {
    if (controller.busy.value || controller.products.isEmpty) return;
    controller.fc.unfocus();
    await Get.toNamed(
      nav_routes.RoutesName.PRODUCT_BULK,
      arguments: {
        'context': widget.context,
        'controller': controller.bulk,
        'fromChat': true,
      },
      preventDuplicates: false,
    );
    if (!mounted) return;
    if (controller.bulk.done.value) {
      Get.back(result: true);
    } else {
      controller.refreshMessages();
    }
  }

  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Main(
      header: Header.page(context, text: 'افزودن محصولات'),
      initState: () async {
        await controller.load();
        return '';
      },
      child: (_) => Obx(
        () => PopScope(
          canPop: !controller.busy.value,
          child: AbsorbPointer(
            absorbing: controller.busy.value,
            child: Stack(
              children: [
                // Chat area - اسکرول‌پذیر
                SizedBox(
                  height: Get.height,
                  child: Obx(() {
                    // اسکرول به آخر وقتی پیام جدید اضافه شود
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (controller.scrollController.hasClients) {
                        controller.scrollController.animateTo(
                          controller.scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: controller.scrollController,
                      reverse: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: controller.chatMessages.length,
                      itemBuilder: (context, index) {
                        return Column(
                          children: [
                            _buildChatBubble(
                              context,
                              controller.chatMessages[index],
                              controller,
                            ),
                            if (index + 1 == controller.chatMessages.length)
                              SizedBox(
                                height: controller.showInputArea.value
                                    ? 150
                                    : 100,
                              ),
                          ],
                        );
                      },
                    );
                  }),
                ),

                // Input area - ثابت در پایین
                Container(
                  alignment: Alignment.bottomCenter,
                  //height: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Obx شناور برای نمایش محصولات اضافه شده
                      Obx(
                        () => controller.products.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child:
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 3,
                                      ),
                                      width: Get.width,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.grey.withValues(alpha: 0.2),
                                            Colors.grey.withValues(alpha: 0.4),
                                          ],
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${controller.products.length} محصول اضافه شد',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              //color: Colors.blue.shade700,
                                            ),
                                          ),
                                          BTN(
                                            onTap: complete,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            navigate: true,
                                            name: controller.bulk.locked
                                                ? 'ادامهٔ ثبت قبلی'
                                                : 'تکمیل اطلاعات و ثبت',
                                          ),
                                        ],
                                      ),
                                    ).asGlass(
                                      clipBorderRadius: BorderRadius.circular(
                                        30,
                                      ),
                                    ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Obx(
                        () => controller.bulk.storageError.value == null
                            ? const SizedBox.shrink()
                            : Text(
                                'ذخیره محلی انجام نشد: ${controller.bulk.storageError.value}',
                              ),
                      ),
                      // Input area - فقط وقتی showInputArea true باشد
                      Obx(
                        () => controller.showInputArea.value
                            ? Container(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Obx(
                                      () => !controller.isEditingMode.value
                                          ? Container(
                                              height: 40,
                                              width: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.grey.withValues(
                                                      alpha: 0.2,
                                                    ),
                                                    Colors.grey.withValues(
                                                      alpha: 0.4,
                                                    ),
                                                  ],
                                                ),
                                                // border: Border.all(
                                                //   color: Colors.grey.withValues(alpha:0.1),
                                                //   width: 1.5,
                                                // ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  IconsaxPlusLinear.send_2,
                                                  color:
                                                      controller
                                                          .hasPendingProducts
                                                          .value
                                                      ? Colors.grey.shade400
                                                      : darkMode.value
                                                      ? Colors.grey.shade300
                                                      : Colors.grey.shade600,
                                                ),
                                                onPressed:
                                                    controller
                                                        .hasPendingProducts
                                                        .value
                                                    ? null
                                                    : () {
                                                        controller.addProduct(
                                                          controller
                                                              .inputController
                                                              .text,
                                                        );
                                                      },
                                              ),
                                            ).asGlass(
                                              clipBorderRadius:
                                                  BorderRadius.circular(30),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Obx(
                                        () => Container(
                                          height: controller.isEditingMode.value
                                              ? 90
                                              : 40,
                                          decoration: BoxDecoration(
                                            //shape: BoxShape.circle,
                                            borderRadius: BorderRadius.circular(
                                              controller.isEditingMode.value
                                                  ? 20
                                                  : 30,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.grey.withValues(
                                                  alpha: 0.05,
                                                ),
                                                Colors.grey.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Obx(
                                                () =>
                                                    controller
                                                        .isEditingMode
                                                        .value
                                                    ? Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              margin:
                                                                  EdgeInsets.only(
                                                                    right: 15,
                                                                    top: 3,
                                                                    bottom: 3,
                                                                  ),
                                                              padding:
                                                                  EdgeInsets.only(
                                                                    right: 6,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                border: Border(
                                                                  right: BorderSide(
                                                                    color:
                                                                        AppColors
                                                                            .blue,
                                                                    width: 2,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'ویرایش',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: AppColors
                                                                          .blue,
                                                                    ),
                                                                    textDirection:
                                                                        TextDirection
                                                                            .rtl,
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Text(
                                                                    controller
                                                                            .editingProductName ??
                                                                        '',
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: Colors
                                                                          .black87,
                                                                    ),
                                                                    textDirection:
                                                                        TextDirection
                                                                            .rtl,
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Container(
                                                            margin:
                                                                EdgeInsets.only(
                                                                  left: 10,
                                                                ),
                                                            child: GestureDetector(
                                                              onTap: () {
                                                                // لغو ویرایش
                                                                controller
                                                                        .editingProductName =
                                                                    null;
                                                                controller
                                                                        .editingId =
                                                                    null;
                                                                controller
                                                                        .isEditingMode
                                                                        .value =
                                                                    false;
                                                                if (controller
                                                                        .previousInputText !=
                                                                    null) {
                                                                  controller
                                                                      .inputController
                                                                      .text = controller
                                                                      .previousInputText!;
                                                                } else {
                                                                  controller
                                                                      .inputController
                                                                      .clear();
                                                                }
                                                                controller
                                                                        .previousInputText =
                                                                    null;
                                                              },
                                                              child: Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                size: 20,
                                                                color: AppColors
                                                                    .grey,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                              Expanded(
                                                child: Obx(
                                                  () => Row(
                                                    children: [
                                                      Obx(
                                                        () =>
                                                            controller
                                                                .isEditingMode
                                                                .value
                                                            ? Container(
                                                                margin:
                                                                    EdgeInsets.only(
                                                                      right:
                                                                          2.8,
                                                                    ),
                                                                child: Container(
                                                                  height: 38,
                                                                  width: 38,
                                                                  decoration: BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    gradient: LinearGradient(
                                                                      begin: Alignment
                                                                          .topLeft,
                                                                      end: Alignment
                                                                          .bottomRight,
                                                                      colors: [
                                                                        AppColors
                                                                            .blue
                                                                            .withValues(
                                                                              alpha: 0.6,
                                                                            ),
                                                                        AppColors
                                                                            .blue
                                                                            .withValues(
                                                                              alpha: 0.9,
                                                                            ),
                                                                      ],
                                                                    ),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors
                                                                            .black
                                                                            .withValues(
                                                                              alpha: 0.08,
                                                                            ),
                                                                        blurRadius:
                                                                            12,
                                                                        offset:
                                                                            const Offset(
                                                                              0,
                                                                              4,
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: IconButton(
                                                                    icon: Icon(
                                                                      Icons
                                                                          .check_rounded,
                                                                      size: 22,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                    onPressed:
                                                                        controller
                                                                            .hasPendingProducts
                                                                            .value
                                                                        ? null
                                                                        : () {
                                                                            controller.addProduct(
                                                                              controller.inputController.text,
                                                                            );
                                                                          },
                                                                  ),
                                                                ).asGlass(clipBorderRadius: BorderRadius.circular(30)),
                                                              )
                                                            : const SizedBox.shrink(),
                                                      ),
                                                      Flexible(
                                                        child: TextField(
                                                          controller: controller
                                                              .inputController,
                                                          autofocus: true,
                                                          focusNode:
                                                              controller.fc,
                                                          enabled: !controller
                                                              .hasPendingProducts
                                                              .value,
                                                          textInputAction:
                                                              TextInputAction
                                                                  .send,
                                                          decoration: InputDecoration(
                                                            hintText: 'نام محصول جدید را بنویسید...',
                                                            hintStyle:
                                                                TextStyle(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                  fontSize: 14,
                                                                ),
                                                            border: InputBorder
                                                                .none,
                                                            enabledBorder:
                                                                InputBorder
                                                                    .none,
                                                            focusedBorder:
                                                                InputBorder
                                                                    .none,
                                                            contentPadding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 10,
                                                                ),
                                                            suffixIcon: Obx(
                                                              () =>
                                                                  !controller
                                                                          .isEditingMode
                                                                          .value &&
                                                                      controller
                                                                          .hasInputText
                                                                          .value
                                                                  ? IconButton(
                                                                      icon: const Icon(
                                                                        Icons
                                                                            .close_rounded,
                                                                        size:
                                                                            20,
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                      onPressed: () {
                                                                        controller
                                                                            .inputController
                                                                            .clear();
                                                                      },
                                                                    )
                                                                  : const SizedBox.shrink(),
                                                            ),
                                                          ),
                                                          textDirection:
                                                              TextDirection.rtl,
                                                          keyboardType:
                                                              TextInputType
                                                                  .text,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            height: 1.65,
                                                          ),
                                                          onSubmitted: (_) {
                                                            controller.addProduct(
                                                              controller
                                                                  .inputController
                                                                  .text,
                                                            );
                                                            controller.fc
                                                                .requestFocus();
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ).asGlass(clipBorderRadius: BorderRadius.circular(controller.isEditingMode.value ? 20 : 30)),
                                      ),
                                    ),

                                    // if (false) const SizedBox(width: 8),
                                    // if (false)
                                    //   Obx(
                                    //     () => Container(
                                    //       height: 40,
                                    //       width: 40,
                                    //       padding: EdgeInsets.zero,
                                    //       decoration: BoxDecoration(
                                    //         shape: BoxShape.circle,
                                    //         gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.grey.withValues(alpha: 0.2), Colors.grey.withValues(alpha: 0.4)]),
                                    //         // border: Border.all(
                                    //         //   color: Colors.grey.withValues(alpha:0.1),
                                    //         //   width: 1.5,
                                    //         // ),
                                    //         boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                                    //       ),
                                    //       child: IconButton(
                                    //         padding: EdgeInsets.all(0),
                                    //         icon: Transform.rotate(
                                    //           angle: 45 * 3.14159 / 180, // 45 درجه
                                    //           child: Icon(
                                    //             Icons.attach_file_rounded,
                                    //             color: controller.hasPendingProducts.value ? Colors.grey.shade400 : Colors.grey.shade700,
                                    //             // size: 22,
                                    //           ),
                                    //         ),
                                    //         onPressed: () {},
                                    //       ),
                                    //     ).asGlass(clipBorderRadius: BorderRadius.circular(30)),
                                    //   ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                //
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _systemMessageBubble(ChatMessage message, {double? marginBottom}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: Get.width * 0.75),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.blue
              : darkMode.value
              ? Colors.grey.shade700
              : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: message.isUser
                ? const Radius.circular(15)
                : const Radius.circular(4),
            bottomRight: message.isUser
                ? const Radius.circular(4)
                : const Radius.circular(15),
          ),
        ),
        child: Text(
          message.text,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: darkMode.value ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(
    BuildContext context,
    ChatMessage message,
    ProductGroupAddController controller,
  ) {
    if (message.isSystemMessage) {
      // پیام سیستم عادی (تایید، تکراری، استقبالی)
      return _systemMessageBubble(message);
    }

    if (message.isDeleteAllConfirmation) {
      // پیام تاییدیه حذف همه محصولات
      message.text = 'آیا مطمئن هستید که می‌خواهید تمام محصولات را حذف کنید؟';
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _systemMessageBubble(message),
            // دکمه‌ها بیرون کادر
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BTN(
                  onTap: () {
                    controller.cancelDeleteAll();
                  },
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  color: Colors.grey.shade500,
                  name: 'لغو',
                ),
                BTN(
                  onTap: controller.confirmDeleteAll,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  color: AppColors.error,
                  name: 'حذف',
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (message.isPendingConfirmation) {
      // پیام تایید محصولات ثابت نشده
      message.text =
          '${controller.products.length} محصولی که قبلا اضافه کرده بودی رو هنوز تایید نهایی نکردی.\nالان میخوای چیکار کنی؟';
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _systemMessageBubble(message, marginBottom: 0),
            // دکمه‌ها بیرون کادر
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BTN(
                  onTap: () {
                    controller.confirmPendingProducts();
                    controller.gotoEndScroll();
                  },
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  borderOnly: true,
                  color: AppColors.primary,
                  name: 'افزودن جدید',
                ),
                BTN(
                  onTap: complete,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  color: AppColors.primary,
                  navigate: true,
                  name: 'تکمیل اطلاعات و ثبت',
                ),
                BTN(
                  onTap: () {
                    controller.clearAllProducts();
                  },
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  //borderOnly: true,
                  color: AppColors.error,
                  name: 'حذف همه',
                ),
              ],
            ),
          ],
        ),
      );
    } else if (message.isDeleteConfirmation) {
      // پیام تاییدیه حذف
      message.text =
          'آیا می‌خواهید "${message.deletingProductName}" را حذف کنید؟';
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _systemMessageBubble(message, marginBottom: 0),
            // دکمه‌ها بیرون کادر
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BTN(
                  onTap: () {
                    controller.chatMessages.removeWhere(
                      (msg) =>
                          msg.isDeleteConfirmation &&
                          msg.deletingProductName ==
                              message.deletingProductName,
                    );
                  },
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  borderOnly: true,
                  color: Colors.grey.shade500,
                  name: 'لغو',
                ),
                BTN(
                  onTap: () async {
                    await controller.removeProductByName(
                      message.deletingProductName!,
                      rowId: message.uuid,
                    );

                    // حذف پیام تاییدیه
                    controller.chatMessages.removeWhere(
                      (msg) =>
                          msg.isDeleteConfirmation &&
                          msg.deletingProductName ==
                              message.deletingProductName,
                    );
                  },
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  color: AppColors.error,
                  name: 'حذف',
                ),
              ],
            ),
          ],
        ),
      );
    } else if (message.isUser) {
      // پیام کاربر (سمت راست، آبی) - با ایکون‌های Edit/Delete
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // پیام
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                decoration: BoxDecoration(
                  color: message.isUser ? AppColors.blue : Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(15),
                    topRight: const Radius.circular(15),
                    bottomLeft: message.isUser
                        ? const Radius.circular(15)
                        : const Radius.circular(4),
                    bottomRight: message.isUser
                        ? const Radius.circular(4)
                        : const Radius.circular(15),
                  ),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ایکون‌های Edit و Delete (سمت چپ)
            Obx(
              () => controller.showInputArea.value
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ایکون Edit
                        InkWell(
                          onTap: () => _showEditInTextField(
                            message.text,
                            controller,
                            rowId: message.uuid,
                          ),
                          borderRadius: BorderRadius.circular(50),
                          child: Icon(
                            IconsaxPlusLinear.edit_2,
                            size: 18,
                            color: Colors.blue.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // ایکون Delete
                        InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: () => _showDeleteInline(
                            message.text,
                            controller,
                            rowId: message.uuid,
                          ),
                          child: Icon(
                            IconsaxPlusLinear.trash,
                            size: 18,
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    )
                  : SizedBox.shrink(),
            ),
          ],
        ),
      );
    } else if (message.isTyping) {
      // حالت Typing (نقاط جرقه زن)
      message.text = '・・・';
      return _systemMessageBubble(message);
    } else {
      return Container();
    }
    // else {
    //   // پیام بات (سمت چپ، خاکستری)
    //   return Align(
    //     alignment: Alignment.centerLeft,
    //     child: Container(
    //       margin: const EdgeInsets.only(bottom: 10),
    //       padding: const EdgeInsets.symmetric(
    //         horizontal: 16,
    //         vertical: 10,
    //       ),
    //       decoration: BoxDecoration(
    //         color: message.isDuplicate ? Colors.red.shade100 : Colors.grey.shade200,
    //         borderRadius: BorderRadius.circular(18),
    //       ),
    //       child: Text(
    //         message.text,
    //         style: TextStyle(
    //           color: message.isDuplicate ? Colors.red.shade700 : Colors.grey.shade700,
    //           fontSize: 13,
    //           fontWeight: FontWeight.w500,
    //         ),
    //         textDirection: TextDirection.rtl,
    //       ),
    //     ),
    //   );
    // }
  }

  void _showDeleteInline(
    String productName,
    ProductGroupAddController controller, {
    String? rowId,
  }) {
    // پیدا کردن ایندکس پیام محصول
    int productMessageIndex = -1;
    for (int i = 0; i < controller.chatMessages.length; i++) {
      if (controller.chatMessages[i].isUser &&
          (rowId == null
              ? controller.chatMessages[i].text == productName
              : controller.chatMessages[i].uuid == rowId)) {
        productMessageIndex = i;
        break;
      }
    }

    // درج تاییدیه حذف درست بعد از پیام محصول
    if (productMessageIndex != -1) {
      controller.chatMessages.insert(
        productMessageIndex + 1,
        ChatMessage(
          text: '',
          isUser: false,
          isDeleteConfirmation: true,
          deletingProductName: productName,
          uuid: rowId,
        ),
      );
    }

    // اسکرول به آخر لیست
    // Future.delayed(const Duration(milliseconds: 300), () {
    //   if (controller.scrollController.hasClients) {
    //     controller.scrollController.animateTo(
    //       controller.scrollController.position.maxScrollExtent+150,
    //       duration: const Duration(milliseconds: 300),
    //       curve: Curves.easeOut,
    //     );
    //   }
    // });
  }

  void _showEditInTextField(
    String productName,
    ProductGroupAddController controller, {
    String? rowId,
  }) {
    // ذخیره متن فعلی TextField
    final previousText = controller.inputController.text;
    controller.previousInputText = previousText;
    controller.editingProductName = productName;
    controller.editingId = rowId;
    controller.isEditingMode.value = true;

    // قرار دادن متن محصول در TextField
    controller.inputController.text = productName;

    // فوکوس روی TextField
    controller.fc.requestFocus();

    // انتخاب تمام متن برای راحتی ویرایش
    controller.inputController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.inputController.text.length,
    );
  }
}

Widget buildProductGroupAddRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductGroupAddScreen(
    context: args.required<BusinessContext>('context'),
    controller: args.optional<ProductBulkController>('controller'),
  );
}
