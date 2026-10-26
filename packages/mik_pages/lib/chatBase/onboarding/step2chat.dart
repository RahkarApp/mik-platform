import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';
import 'package:glass/glass.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:hive/hive.dart';
import 'package:mik_data/models/models.dart';
import 'dart:convert';

import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/chatBase/common/chatMessageModel.dart';

class Step2ChatController extends GetxController {
  final RxList<ChatMessage> chatMessages = <ChatMessage>[].obs;
  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final RxBool hasInputText = false.obs;
  final RxBool showInputArea = true.obs;

  // Edit Mode State
  final RxBool isEditingMode = false.obs;
  ChatMessage? editingMessage;
  String? previousInputText;

  // Data storage
  // Each item is a Map with 'uuid' and 'data' (data format: 'name:amount' or just 'amount' for capital)
  final RxList<Map<String, String>> debts = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> claims = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> cashCapital = <Map<String, String>>[].obs;

  final Rx<ChatStage> currentStage = ChatStage.debts.obs;
  final RxBool hasAddedNewItemsInConfirmation = false.obs;
  final FocusNode fc = FocusNode();

  Step2ChatController() {
    inputController.addListener(() {
      hasInputText.value = inputController.text.isNotEmpty;
    });
    //  _initializeWelcomeMessage();
  }

  @override
  void onInit() {
    super.onInit();

    // Load draft data if exists
    loadDraft();

    // Auto-scroll when messages change
    ever(chatMessages, (_) => _scrollToBottom());
  }

  @override
  void onReady() {
    super.onReady();
    // Request focus on start
    fc.requestFocus();
  }

  void _initializeWelcomeMessage() {
    _showTypingAndMessage(
      "${product.isNotEmpty ? 'خوب عالی شد🥳\nتمام محصولات و موجودی اونها ثبت شد' : 'خوب هیچ محصولی نداشتی!\nبریم سراغ بقیه موارد...'}\n\nبرای شروع، لطفا لیست \"بدهی‌ها\" رو وارد کن.\nفرمت صحیح: نام شخص + مبلغ (مثال: نادر تهرانی ۵۰۰۰۰)\nمبالغ رو به تومان وارد کن (فقط نام و عدد)\nهر وقت تموم شد دکمه \"تایید و مرحله بعد\" رو بزن.\nنگران نباش اگر چیزی جاموند بازم در مرحله آخری میتونی وارد کنی.",
    );
    _showTypingAndMessage('من حواسم هست، هرجا از برنامه رفتی بیرون  اطلاعات رو نگه میدارم تا برگردی و تکمیلش کنی.');
  }

  String _normalizeNumber(String text) {
    return text
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
  }

  void sendMessage(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    // Check for "Nadarom" command to skip stage
    final skipKeywords = ['ندارم', 'نیست', 'هیچی', 'نداریم', 'خالی', 'بعدی', 'تموم', 'پایان'];
    if (skipKeywords.contains(trimmedText)) {
      inputController.clear();
      // Optionally show a user message for "ندارم" before skipping?
      // Or just skip. Let's show it as a user message then skip.
      chatMessages.add(ChatMessage(text: text, isUser: true, stage: currentStage.value));
      nextStage();
      return;
    }

    if (isEditingMode.value && editingMessage != null) {
      _updateMessage(trimmedText);
    } else {
      _addNewMessage(trimmedText);
    }
  }

  void _addNewMessage(String text) {
    // Determine list index before adding (it will be the next index)
    int newIndex = 0;
    switch (currentStage.value) {
      case ChatStage.debts:
        newIndex = debts.length;
        break;
      case ChatStage.claims:
        newIndex = claims.length;
        break;
      case ChatStage.cashCapital:
        newIndex = cashCapital.length;

        break;
      case ChatStage.confirmation:
        // Index depends on type, resolved in _processConfirmation
        newIndex = 0;
        break;
      case ChatStage.finished:
        break;
    }

    final message = ChatMessage(
      text: text, // Will be updated by _process... if valid
      isUser: true,
      stage: currentStage.value,
      listIndex: newIndex,
      originalText: text,
      uuid: ID.uidNew(),
    );

    // Process input based on stage
    final normalizedText = _normalizeNumber(text);
    bool isValid = false;

    switch (currentStage.value) {
      case ChatStage.debts:
        isValid = _processDebtOrClaim(normalizedText, message: message);
        break;
      case ChatStage.claims:
        isValid = _processDebtOrClaim(normalizedText, message: message);
        break;
      case ChatStage.cashCapital:
        isValid = _processCashCapital(normalizedText, message: message);
        break;
      case ChatStage.confirmation:
        isValid = _processConfirmation(normalizedText, message: message);
        break;
      case ChatStage.finished:
        break;
    }

    if (isValid) {
      chatMessages.add(message);
      inputController.clear();
      // Save draft immediately after adding message
      saveDraft();
      // _scrollToBottom(); // Handled by ever()
    }
  }

  void _updateMessage(String text) {
    final message = editingMessage!;
    final normalizedText = _normalizeNumber(text);
    bool isValid = false;

    // Temporarily remove old data to validate new data (optional, but good for consistency)
    // Actually, we just overwrite the data at listIndex.

    // Use the stage of the message being edited
    switch (editingMessage!.stage!) {
      case ChatStage.debts:
      case ChatStage.claims:
        isValid = _processDebtOrClaim(normalizedText, message: message, isUpdate: true, stage: editingMessage!.stage);
        break;
      case ChatStage.cashCapital:
        isValid = _processCashCapital(normalizedText, message: message, isUpdate: true);
        break;
      case ChatStage.confirmation:
        isValid = _processConfirmation(normalizedText, message: message, isUpdate: true);
        break;
      case ChatStage.finished:
        break;
    }

    if (isValid) {
      editingMessage!.text = text;

      // If we are in confirmation stage, any edit should trigger a summary update
      if (currentStage.value == ChatStage.confirmation) {
        _updateSummary();
      }

      cancelEdit();
      // Save draft after edit
      saveDraft();
    } else {
      // Revert if invalid
      // For now, just show a snackbar, the message text won't change
      Get.snackbar('خطا', 'ویرایش نامعتبر است. لطفا فرمت صحیح را وارد کنید.');
    }
  }

  bool _processDebtOrClaim(String text, {required ChatMessage message, bool isUpdate = false, ChatStage? stage}) {
    final targetStage = stage ?? currentStage.value;
    bool isDebt = targetStage == ChatStage.debts;

    final RegExp numberRegex = RegExp(r'[0-9]+');
    final match = numberRegex.firstMatch(text);

    String? name;
    String? amount;

    if (match != null) {
      amount = match.group(0);
      final namePart = text.replaceRange(match.start, match.end, '').trim();
      if (namePart.isNotEmpty) {
        name = namePart;
      }
    }

    if (amount != null && name != null && name.isNotEmpty) {
      final formattedText = isDebt ? '✅ ${Price.showWithCurrency(int.parse(amount))} بدهی شما به $name ثبت شد' : '✅ ${Price.showWithCurrency(int.parse(amount))} طلب شما از $name ثبت شد';

      // We don't change user message text to system message text.
      // User message stays as input. System message confirms it.
      // But wait, the previous logic added a SYSTEM message for confirmation.
      // The user message was just the input.

      // If we are editing, we update the USER message text to the new input.
      // And we update the DATA in the list.
      // We do NOT show a new system message for edits, usually.
      // Or maybe we do? Let's just update the user message and data.

      message.text = text; // User sees what they typed

      if (isUpdate) {
        final targetList = isDebt ? debts : claims;
        final index = targetList.indexWhere((item) => item['uuid'] == message.uuid);
        if (index != -1) {
          targetList[index] = {'uuid': message.uuid!, 'data': '$name:$amount'};
        }

        // Update associated system message
        final msgIndex = chatMessages.indexOf(message);
        if (msgIndex != -1 && msgIndex + 1 < chatMessages.length) {
          final nextMsg = chatMessages[msgIndex + 1];
          if (nextMsg.isSystemMessage) {
            nextMsg.text = '$formattedText (ویرایش شد)';
          }
        }
      } else {
        final uuid = message.uuid ?? ID.uidNew();
        message.uuid = uuid;
        if (isDebt) {
          debts.add({'uuid': uuid, 'data': '$name:$amount'});
        } else {
          claims.add({'uuid': uuid, 'data': '$name:$amount'});
        }
        _showSystemMessage(formattedText);
      }
      return true;
    } else {
      if (!isUpdate) {
        _showSystemMessage('⚠️ فرمت وارد شده صحیح نیست.\nلطفا نام و مبلغ را وارد کنید (مثال: علی ۵۰۰۰۰)\nمبالغ رو به تومان وارد کن (فقط نام و عدد)');
      } else {
        // Show snackbar or error for edit?
        Get.snackbar('خطا', 'فرمت وارد شده صحیح نیست');
      }
      return false;
    }
  }

  bool _processCashCapital(String text, {required ChatMessage message, bool isUpdate = false}) {
    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isNotEmpty && int.tryParse(cleanText) != null) {
      message.text = text;

      if (isUpdate) {
        // Find and update by UUID
        final index = cashCapital.indexWhere((item) => item['uuid'] == message.uuid);
        if (index != -1) {
          cashCapital[index] = {'uuid': message.uuid!, 'data': cleanText};
        }

        int total = 0;
        for (var item in cashCapital) {
          total += int.tryParse(item['data']!) ?? 0;
        }

        final formattedText = '✅ سرمایه نقدی به مبلغ ${Price.showWithCurrency(int.parse(cleanText))} ثبت شد';

        // Update associated system message
        final msgIndex = chatMessages.indexOf(message);
        if (msgIndex != -1 && msgIndex + 1 < chatMessages.length) {
          final nextMsg = chatMessages[msgIndex + 1];
          if (nextMsg.isSystemMessage) {
            nextMsg.text = '$formattedText (ویرایش شد)';
          }
        }
      } else {
        final uuid = message.uuid ?? ID.uidNew();
        message.uuid = uuid;
        cashCapital.add({'uuid': uuid, 'data': cleanText});

        int total = 0;
        for (var item in cashCapital) {
          total += int.tryParse(item['data']!) ?? 0;
        }

        _showSystemMessage('✅ سرمایه نقدی به مبلغ ${Price.showWithCurrency(int.parse(cleanText))} ثبت شد\n💰 مجموع سرمایه تا الان: ${Price.showWithCurrency(total)}');
      }
      return true;
    } else {
      if (!isUpdate) {
        _showSystemMessage('⚠️ لطفا فقط عدد وارد کنید (مثال: ۱۰۰۰۰۰۰)\nبه تومان');
        inputController.clear();
      } else {
        Get.snackbar('خطا', 'لطفا فقط عدد وارد کنید');
      }
      return false;
    }
  }

  bool _processConfirmation(String text, {required ChatMessage message, bool isUpdate = false}) {
    // Check for prefixes or infer type
    bool isDebt = false;
    bool isClaim = false;
    bool isCapital = false;
    String cleanText = text;

    if (text.startsWith('بدهی')) {
      isDebt = true;
      cleanText = text.substring(4).trim();
    } else if (text.startsWith('طلب')) {
      isClaim = true;
      cleanText = text.substring(3).trim();
    } else if (text.startsWith('سرمایه')) {
      isCapital = true;
      cleanText = text.substring(6).trim();
    } else {
      // If updating, try to infer from old message text if prefix is missing
      if (isUpdate) {
        if (message.originalText?.startsWith('بدهی') ?? message.text.startsWith('بدهی')) {
          isDebt = true;
        } else if (message.originalText?.startsWith('طلب') ?? message.text.startsWith('طلب')) {
          isClaim = true;
        } else if (message.originalText?.startsWith('سرمایه') ?? message.text.startsWith('سرمایه')) {
          isCapital = true;
        }

        // If inferred, use the whole text as cleanText (since no new prefix)
        // But wait, cleanText needs to be stripped of prefix if it exists.
        // If user removed prefix, cleanText is just the text.
        // If user kept prefix, we already handled it above.
        // So here, cleanText is correct as `text`.
      }

      if (!isDebt && !isClaim && !isCapital) {
        if (!isUpdate) {
          _showSystemMessage('⚠️ لطفا نوع را مشخص کنید (بدهی، طلب یا سرمایه).\nاز دکمه‌های پایین استفاده کنید.\n اول تایپ کن و بعد دکمه‌های بالا رو بزن!');
        } else {
          Get.snackbar('خطا', 'فرمت وارد شده صحیح نیست. لطفا نوع را مشخص کنید.');
        }
        return false;
      }
    }

    if (isCapital) {
      // Capital logic
      final amountText = cleanText.replaceAll(RegExp(r'[^0-9]'), '');
      if (amountText.isNotEmpty) {
        if (!isUpdate) {
          final uuid = message.uuid ?? ID.uidNew();
          message.uuid = uuid;
          message.listIndex = cashCapital.length;
          cashCapital.add({'uuid': uuid, 'data': amountText});
        } else {
          final index = cashCapital.indexWhere((item) => item['uuid'] == message.uuid);
          if (index != -1) {
            cashCapital[index] = {'uuid': message.uuid!, 'data': amountText};
          }
        }

        if (currentStage.value == ChatStage.confirmation) {
          _updateSummary();
          if (!isUpdate) hasAddedNewItemsInConfirmation.value = true;
        }

        int total = 0;
        for (var item in cashCapital) {
          total += int.tryParse(item['data']!) ?? 0;
        }

        // Only show system message if adding new
        if (!isUpdate) {
          _showSystemMessage('✅ سرمایه جدید اضافه شد.\n💰 مجموع سرمایه: ${Price.showWithCurrency(total)}');
        }
        return true;
      }
    } else {
      // Debt/Claim logic
      final RegExp numberRegex = RegExp(r'[0-9]+');
      final match = numberRegex.firstMatch(cleanText);
      String? name;
      String? amount;

      if (match != null) {
        amount = match.group(0);
        final namePart = cleanText.replaceRange(match.start, match.end, '').trim();
        if (namePart.isNotEmpty) name = namePart;
      }

      if (amount != null && name != null) {
        if (isUpdate) {
          // Find and update by UUID
          final targetList = isDebt ? debts : claims;
          final index = targetList.indexWhere((item) => item['uuid'] == message.uuid);
          if (index != -1) {
            targetList[index] = {'uuid': message.uuid!, 'data': '$name:$amount'};
          }
        } else {
          final uuid = message.uuid ?? ID.uidNew();
          message.uuid = uuid;
          if (isDebt) {
            message.listIndex = debts.length;
            debts.add({'uuid': uuid, 'data': '$name:$amount'});
          } else {
            message.listIndex = claims.length;
            claims.add({'uuid': uuid, 'data': '$name:$amount'});
          }
        }

        if (currentStage.value == ChatStage.confirmation) {
          _updateSummary();
          if (!isUpdate) hasAddedNewItemsInConfirmation.value = true;
        }

        if (!isUpdate) {
          final formattedText = isDebt
              ? '✅ بدهی جدید به $name به مبلغ ${Price.showWithCurrency(int.parse(amount))} ثبت شد'
              : '✅ طلب جدید از $name به مبلغ ${Price.showWithCurrency(int.parse(amount))} ثبت شد';
          _showSystemMessage(formattedText);
        }
        return true;
      }
    }

    if (!isUpdate) _showSystemMessage('⚠️ فرمت صحیح نیست.');
    return false;
  }

  void addPrefix(String prefix) {
    final currentText = inputController.text;
    if (currentText.isEmpty) {
      inputController.text = '$prefix ';
    } else {
      if (!currentText.startsWith('بدهی') && !currentText.startsWith('طلب') && !currentText.startsWith('سرمایه')) {
        inputController.text = '$prefix $currentText';
      } else {
        // Replace existing prefix
        if (currentText.startsWith('بدهی')) {
          inputController.text = currentText.replaceFirst('بدهی', prefix);
        } else if (currentText.startsWith('طلب')) {
          inputController.text = currentText.replaceFirst('طلب', prefix);
        } else if (currentText.startsWith('سرمایه')) {
          inputController.text = currentText.replaceFirst('سرمایه', prefix);
        }
      }
    }
    inputController.selection = TextSelection.fromPosition(TextPosition(offset: inputController.text.length));
    fc.requestFocus();
  }

  void sendWithPrefix(String prefix) {
    final text = inputController.text.trim();
    if (text.isEmpty) {
      Alert.error('اول تایپ کن و بعد دکمه رو بزن!');
      // Maybe show error? Or just focus?
      fc.requestFocus();
      return;
    }

    // Check if user already typed prefix
    if (text.startsWith(prefix)) {
      sendMessage(text);
    } else {
      // If user typed "Ali 10000" and clicked "Debt", send "Debt Ali 10000"
      // But if user typed "Debt Ali 10000" and clicked "Debt", send as is.
      // Also handle if user typed "Claim Ali 10000" and clicked "Debt" -> replace?

      String cleanText = text;
      if (text.startsWith('بدهی')) {
        cleanText = text.substring(4).trim();
      } else if (text.startsWith('طلب')) {
        cleanText = text.substring(3).trim();
      } else if (text.startsWith('سرمایه')) {
        cleanText = text.substring(6).trim();
      }

      sendMessage('$prefix $cleanText');
    }
  }

  void startEdit(ChatMessage message) {
    isEditingMode.value = true;
    editingMessage = message;
    previousInputText = inputController.text;
    inputController.text = message.originalText ?? message.text;
    fc.requestFocus();
  }

  void cancelEdit() {
    isEditingMode.value = false;
    editingMessage = null;
    inputController.text = previousInputText ?? '';
    previousInputText = null;
    // fc.unfocus(); // Removed to prevent keyboard loop
  }

  void deleteMessage(ChatMessage message) {
    // Identify type and remove from data list
    bool isDebt = false;
    bool isClaim = false;
    bool isCapital = false;

    if (message.stage == ChatStage.debts) {
      isDebt = true;
    } else if (message.stage == ChatStage.claims) {
      isClaim = true;
    } else if (message.stage == ChatStage.cashCapital) {
      isCapital = true;
    } else if (message.stage == ChatStage.confirmation) {
      if (message.text.startsWith('بدهی')) {
        isDebt = true;
      } else if (message.text.startsWith('طلب')) {
        isClaim = true;
      } else if (message.text.startsWith('سرمایه')) {
        isCapital = true;
      }
    }

    // Remove by UUID instead of index
    if (isDebt) {
      debts.removeWhere((item) => item['uuid'] == message.uuid);
    } else if (isClaim) {
      claims.removeWhere((item) => item['uuid'] == message.uuid);
    } else if (isCapital) {
      cashCapital.removeWhere((item) => item['uuid'] == message.uuid);
    } else {
      return; // Unknown type
    }

    chatMessages.remove(message);

    // Global Re-indexing
    // We must re-index ALL messages that match the deleted type, preserving their relative order.
    int newDebtIndex = 0;
    int newClaimIndex = 0;
    int newCapitalIndex = 0;

    for (var msg in chatMessages) {
      if (!msg.isUser) continue; // Skip system messages

      bool msgIsDebt = false;
      bool msgIsClaim = false;
      bool msgIsCapital = false;

      if (msg.stage == ChatStage.debts) {
        msgIsDebt = true;
      } else if (msg.stage == ChatStage.claims) {
        msgIsClaim = true;
      } else if (msg.stage == ChatStage.cashCapital) {
        msgIsCapital = true;
      } else if (msg.stage == ChatStage.confirmation) {
        if (msg.text.startsWith('بدهی')) {
          msgIsDebt = true;
        } else if (msg.text.startsWith('طلب')) {
          msgIsClaim = true;
        } else if (msg.text.startsWith('سرمایه')) {
          msgIsCapital = true;
        }
      }

      if (msgIsDebt) msg.listIndex = newDebtIndex++;
      if (msgIsClaim) msg.listIndex = newClaimIndex++;
      if (msgIsDebt) msg.listIndex = newDebtIndex++;
      if (msgIsClaim) msg.listIndex = newClaimIndex++;
      if (msgIsCapital) msg.listIndex = newCapitalIndex++;
    }

    if (currentStage.value == ChatStage.confirmation) _updateSummary();

    // Save draft after delete
    saveDraft();
  }

  void _updateSummary() {
    // Calculate totals
    int totalDebts = 0;
    for (var d in debts) {
      final parts = d['data']!.split(':');
      if (parts.length > 1) totalDebts += int.tryParse(parts[1]) ?? 0;
    }
    int totalClaims = 0;
    for (var c in claims) {
      final parts = c['data']!.split(':');
      if (parts.length > 1) totalClaims += int.tryParse(parts[1]) ?? 0;
    }
    int totalCapital = 0;
    for (var c in cashCapital) {
      totalCapital += int.tryParse(c['data']!) ?? 0;
    }

    final summaryText =
        '📋 خلاصه وضعیت:\n\n'
        '🔴 مجموع بدهی‌ها: ${Price.showWithCurrency(totalDebts)}\n'
        '🟢 مجموع طلب‌ها: ${Price.showWithCurrency(totalClaims)}\n'
        '💰 سرمایه نقدی: ${Price.showWithCurrency(totalCapital)}\n\n'
        'اگر چیزی جا مونده، همین الان میتونی وارد کنی (با دکمه‌های پایین).\n'
        'اگر همه چی درسته، دکمه "تایید نهایی" رو بزن.';

    // Find the last summary message
    try {
      final lastSummary = chatMessages.lastWhere((msg) => msg.isSystemMessage && msg.text.startsWith('📋 خلاصه وضعیت'));
      lastSummary.text = summaryText;
      chatMessages.refresh();
    } catch (e) {
      // If not found (shouldn't happen in confirmation stage), maybe send new?
      // But we only call this in confirmation stage where summary is already sent.
    }
  }

  void _showSystemMessage(String text) {
    Future.delayed(const Duration(milliseconds: 500), () {
      chatMessages.add(ChatMessage(text: text, isUser: false, isSystemMessage: true));
      // _scrollToBottom(); // Handled by ever()
    });
  }

  Future<void> nextStage() async {
    saveDraft();
    switch (currentStage.value) {
      case ChatStage.debts:
        currentStage.value = ChatStage.claims;
        _showTypingAndMessage('✅ بسیار عالی! بدهی‌ها ثبت شد.\n\nحالا لیست "طلب‌ها" رو وارد کن.\n(فرمت: نام شخص + مبلغ)\nمبالغ رو به تومان وارد کن (فقط نام و عدد)');
        break;
      case ChatStage.claims:
        currentStage.value = ChatStage.cashCapital;
        _showTypingAndMessage('✅ طلب‌ها هم ثبت شد.\n\nدر مرحله آخر، میزان "سرمایه نقدی" رو وارد کن.\n(فقط عدد وارد کن)');
        break;

      case ChatStage.cashCapital:
        currentStage.value = ChatStage.confirmation;

        // Calculate totals
        int totalDebts = 0;
        for (var d in debts) {
          final parts = d['data']!.split(':');
          if (parts.length > 1) totalDebts += int.tryParse(parts[1]) ?? 0;
        }
        int totalClaims = 0;
        for (var c in claims) {
          final parts = c['data']!.split(':');
          if (parts.length > 1) totalClaims += int.tryParse(parts[1]) ?? 0;
        }
        int totalCapital = 0;
        for (var c in cashCapital) {
          totalCapital += int.tryParse(c['data']!) ?? 0;
        }

        _showTypingAndMessage(
          '📋 خلاصه وضعیت:\n\n'
          '🔴 مجموع بدهی‌ها: ${Price.showWithCurrency(totalDebts)}\n'
          '🟢 مجموع طلب‌ها: ${Price.showWithCurrency(totalClaims)}\n'
          '💰 سرمایه نقدی: ${Price.showWithCurrency(totalCapital)}\n\n'
          'اگر چیزی جا مونده، همین الان میتونی وارد کنی (با دکمه‌های پایین).\n'
          'اگر همه چی درسته، دکمه "تایید نهایی" رو بزن.',
        );
        break;
      case ChatStage.confirmation:
        if (hasAddedNewItemsInConfirmation.value) {
          // Show summary again
          hasAddedNewItemsInConfirmation.value = false;

          // Calculate totals
          int totalDebts = 0;
          for (var d in debts) {
            final parts = d['data']!.split(':');
            if (parts.length > 1) totalDebts += int.tryParse(parts[1]) ?? 0;
          }
          int totalClaims = 0;
          for (var c in claims) {
            final parts = c['data']!.split(':');
            if (parts.length > 1) totalClaims += int.tryParse(parts[1]) ?? 0;
          }
          int totalCapital = 0;
          for (var c in cashCapital) {
            totalCapital += int.tryParse(c['data']!) ?? 0;
          }

          _showTypingAndMessage(
            '📋 خلاصه وضعیت جدید:\n\n'
            '🔴 مجموع بدهی‌ها: ${Price.showWithCurrency(totalDebts)}\n'
            '🟢 مجموع طلب‌ها: ${Price.showWithCurrency(totalClaims)}\n'
            '💰 سرمایه نقدی: ${Price.showWithCurrency(totalCapital)}\n\n'
            'اگر همه چی درسته، دکمه "تایید نهایی" رو بزن.',
          );
        } else {
          currentStage.value = ChatStage.finished;
          showInputArea.value = false;
          _showTypingAndMessage('⏳درحال ذخیره اطلاعات...');
          await saveData();
          _showTypingAndMessage('🎉 تبریک! تمام اطلاعات با موفقیت ثبت شد.\n\nمیتونی به داشبورد برگردی.');

          // Clear draft after final confirmation
          await clearDraft();
          Get.back();
        }
        break;
      case ChatStage.finished:
        break;
    }
  }

  saveData() async {
    for (var d in debts) {
      final [name, amount] = d['data']!.split(':');
      String uid = d['uuid'] ?? ID.uidNew();
      int id = await savePerson(uid, name, '-');
      await saveBill('-', uid, id, int.tryParse(amount) ?? 0);
    }
    for (var c in claims) {
      final [name, amount] = c['data']!.split(':');
      String uid = c['uuid'] ?? ID.uidNew();
      int id = await savePerson(uid, name, 'customer');
      await saveBill(uid, '-', id, int.tryParse(amount) ?? 0);
    }
    String partnerUID = person.getAt(0)!.uid ?? '-';
    for (var c in cashCapital) {
      final a = c['data'];
      int amount = int.tryParse(c['data']!) ?? 0;
      if (amount > 0) {
        var f = PartnerTransactionDB(
          id: ID.endId(partnerTransaction),
          uid: ID.uidNew(),
          inserter: 0,
          partnerUID: partnerUID,
          amount: amount,
          status: 'invest',
          date: DateTime.now().toIso8601String(),
          description: 'اول دوره',
        );
        await SaveHelper.save(f);
      }
    }
    await clearDraft();
    Get.back();
    Alert.success('تمام اطلاعات با موفقیت اضافه شد.');
    await Future.delayed(Duration(milliseconds: 1500), () {
      Alert.notif(title: '🚀از میک لذت ببرید...', message: 'میک دستیار تمام عیار شماست🌹');
    });
  }

  savePerson(String uid, String name, type) async {
    var p = PersonDB(
      id: ID.endId(person),
      uid: uid,
      name: name,
      inserter: 0,
      isAdmin: false,
      isSupplier: type != 'customer',
      isPartner: false,
      isCustomer: type == 'customer',
      isMarketer: false,
      isService: type != 'customer',
      org: false,
      date: DateTime.now().toIso8601String(),
    );
    await SaveHelper.save(p);
    return p.id;
  }

  saveBill(String debtorUID, String creditorUID, pid, int amount) async {
    if (amount > 0) {
      var b = BillDB(
        id: ID.endId(bill),
        uid: ID.uidNew(),
        toUID: '1',
        inserter: 0,
        debtor: debtorUID == '-' ? 0 : pid,
        creditor: debtorUID == '-' ? pid : 0,
        debtorUID: debtorUID,
        creditorUID: creditorUID,
        total: amount,
        paid: 0,
        unPaid: amount,
        type: debtorUID == '-' ? 'debt' : 'credit',
        date: DateTime.now().toIso8601String(),
        meta: {},
      );
      await SaveHelper.save(b);
    }
  }

  void _showTypingAndMessage(String message) {
    chatMessages.add(ChatMessage(text: '', isUser: false, isTyping: true));
    // _scrollToBottom(); // Handled by ever()

    Future.delayed(const Duration(milliseconds: 700), () {
      if (chatMessages.isNotEmpty && chatMessages.last.isTyping) {
        chatMessages.removeLast();
      }
      chatMessages.add(ChatMessage(text: message, isUser: false, isSystemMessage: true, isWelcomeMessage: true));
      // _scrollToBottom(); // Handled by ever()
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(scrollController.position.maxScrollExtent + 150, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void onClose() {
    // Save draft before closing
    saveDraft();

    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // Draft Storage Methods
  Future<void> saveDraft() async {
    try {
      final box = await Hive.openBox<OnboardingDraftDB>('onboardingDraft');

      final draft = OnboardingDraftDB(
        uid: 'draft_001', // Single draft for now
        createdDate: DateTime.now().toIso8601String(),
        debtsJson: jsonEncode(debts.toList()),
        claimsJson: jsonEncode(claims.toList()),
        cashCapitalJson: jsonEncode(cashCapital.toList()),
        currentStage: currentStage.value.toString().split('.').last,
        chatMessagesJson: jsonEncode(
          chatMessages
              .map(
                (msg) => {
                  'text': msg.text,
                  'isUser': msg.isUser,
                  'isSystemMessage': msg.isSystemMessage,
                  'isWelcomeMessage': msg.isWelcomeMessage,
                  'stage': msg.stage?.toString().split('.').last,
                  'listIndex': msg.listIndex,
                  'originalText': msg.originalText,
                  'uuid': msg.uuid,
                },
              )
              .toList(),
        ),
      );

      await box.put('draft_001', draft);
    } catch (e) {}
  }

  Future<void> loadDraft() async {
    try {
      final box = await Hive.openBox<OnboardingDraftDB>('onboardingDraft');
      final draft = box.get('draft_001');

      if (draft != null) {
        // Load data
        if (draft.debtsJson != null) {
          final debtsList = jsonDecode(draft.debtsJson!) as List;
          debts.value = debtsList.map((e) => Map<String, String>.from(e)).toList();
        }

        if (draft.claimsJson != null) {
          final claimsList = jsonDecode(draft.claimsJson!) as List;
          claims.value = claimsList.map((e) => Map<String, String>.from(e)).toList();
        }

        if (draft.cashCapitalJson != null) {
          final capitalList = jsonDecode(draft.cashCapitalJson!) as List;
          cashCapital.value = capitalList.map((e) => Map<String, String>.from(e)).toList();
        }

        // Load current stage
        if (draft.currentStage != null) {
          switch (draft.currentStage!) {
            case 'debts':
              currentStage.value = ChatStage.debts;
              break;
            case 'claims':
              currentStage.value = ChatStage.claims;
              break;
            case 'cashCapital':
              currentStage.value = ChatStage.cashCapital;
              break;
            case 'confirmation':
              currentStage.value = ChatStage.confirmation;
              break;
            default:
              currentStage.value = ChatStage.debts;
          }
        }

        // Load chat messages
        if (draft.chatMessagesJson != null) {
          final messagesList = jsonDecode(draft.chatMessagesJson!) as List;
          chatMessages.value = messagesList.map((msgData) {
            ChatStage? stage;
            if (msgData['stage'] != null) {
              switch (msgData['stage']) {
                case 'confirmation':
                  stage = ChatStage.confirmation;
                  break;
                case 'cashCapital':
                  stage = ChatStage.cashCapital;
                  break;
                case 'debts':
                  stage = ChatStage.debts;
                  break;
                case 'claims':
                  stage = ChatStage.claims;
                  break;
              }
            }

            return ChatMessage(
              text: msgData['text'] ?? '',
              isUser: msgData['isUser'] ?? false,
              isSystemMessage: msgData['isSystemMessage'] ?? false,
              isWelcomeMessage: msgData['isWelcomeMessage'] ?? false,
              stage: stage,
              listIndex: msgData['listIndex'],
              originalText: msgData['originalText'],
              uuid: msgData['uuid'],
            );
          }).toList();
        }
      } else {
        _initializeWelcomeMessage();
      }
      if (debts.isEmpty && claims.isEmpty && cashCapital.isEmpty && chatMessages.isEmpty) {
        _initializeWelcomeMessage();
      }
    } catch (e) {}
  }

  Future<void> clearDraft() async {
    try {
      final box = await Hive.openBox<OnboardingDraftDB>('onboardingDraft');
      await box.delete('draft_001');
    } catch (e) {}
  }
}

class Step2ChatScreen extends StatelessWidget {
  const Step2ChatScreen({super.key});

  Widget _buildChatBubble(BuildContext context, ChatMessage message, Step2ChatController controller) {
    if (message.isTyping) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
          ),
          child: const Text('...'), // Simple typing indicator
        ),
      );
    }

    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // Changed to end for user messages
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Message Bubble
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: BoxConstraints(maxWidth: Get.width * 0.75),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15), bottomLeft: Radius.circular(15), bottomRight: Radius.circular(4)),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Edit/Delete Icons
            Obx(
              () => controller.showInputArea.value
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Icon
                        InkWell(
                          onTap: () => controller.startEdit(message),
                          borderRadius: BorderRadius.circular(50),
                          child: Icon(IconsaxPlusLinear.edit_2, size: 18, color: Colors.blue.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(width: 10),
                        // Delete Icon
                        InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: () => controller.deleteMessage(message),
                          child: Icon(IconsaxPlusLinear.trash, size: 18, color: Colors.red.withValues(alpha: 0.5)),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    // System Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: Get.width * 0.75),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(15), bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(Step2ChatController());

    return Main(
      header: Header.page(context, text: 'اطلاعات تکمیلی'),
      initState: () async {
        return '';
      },
      child: (_) => Stack(
        children: [
          // Chat area
          SizedBox(
            height: Get.height,
            child: Obx(() {
              // Auto-scroll when new messages arrive
              // WidgetsBinding.instance.addPostFrameCallback removed - handled in controller

              return ListView.builder(
                controller: controller.scrollController,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: controller.currentStage.value == ChatStage.confirmation ? 180 : 120, // Increased space for confirmation
                ),
                itemCount: controller.chatMessages.length,
                itemBuilder: (context, index) {
                  return _buildChatBubble(context, controller.chatMessages[index], controller);
                },
              );
            }),
          ),

          // Input area
          Container(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Next Stage Button
                Obx(() {
                  if (controller.currentStage.value == ChatStage.finished) {
                    return const SizedBox.shrink();
                  }

                  // Only show if list is not empty or user wants to skip?
                  // Assuming user must enter at least one item or we allow empty?
                  // For now, always show "Next" to allow skipping or finishing.
                  // Or maybe show it only when items are added?
                  // Let's show it always as "Confirm and Next"

                  // Always show the button to allow skipping

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      width: Get.width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.grey.withValues(alpha: 0.2), Colors.grey.withValues(alpha: 0.4)]),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_getStageSummary(controller), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          BTN(
                            onTap: () {
                              controller.nextStage();
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            name: controller.currentStage.value == ChatStage.confirmation
                                ? (controller.hasAddedNewItemsInConfirmation.value ? 'مشاهده خلاصه و ثبت' : 'تایید نهایی و ثبت')
                                : 'تایید و مرحله بعد',
                          ),
                        ],
                      ),
                    ).asGlass(clipBorderRadius: BorderRadius.circular(30)),
                  );
                }),

                // Chips for Confirmation Stage
                Obx(() {
                  if (controller.currentStage.value == ChatStage.confirmation && controller.showInputArea.value) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildChip(label: '💰 سرمایه', onTap: () => controller.sendWithPrefix('سرمایه')),
                          const SizedBox(width: 8),
                          _buildChip(label: '🟢 طلب', onTap: () => controller.sendWithPrefix('طلب')),
                          const SizedBox(width: 8),
                          _buildChip(label: '🔴 بدهی', onTap: () => controller.sendWithPrefix('بدهی')),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // Input Field
                Obx(
                  () => controller.showInputArea.value
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Column(
                            children: [
                              // Editing Indicator
                              if (controller.isEditingMode.value)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.blue, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ویرایش',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.blue),
                                          ),
                                          Text(
                                            controller.editingMessage?.originalText ?? '',
                                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: controller.cancelEdit,
                                        child: const Icon(Icons.close, size: 18, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Send/Check Button
                                  Obx(() {
                                    if (controller.currentStage.value == ChatStage.confirmation && !controller.isEditingMode.value) return const SizedBox.shrink();

                                    return Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            controller.isEditingMode.value ? AppColors.blue.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.2),
                                            controller.isEditingMode.value ? AppColors.blue.withValues(alpha: 0.9) : Colors.grey.withValues(alpha: 0.4),
                                          ],
                                        ),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          controller.isEditingMode.value ? Icons.check_rounded : IconsaxPlusLinear.send_2,
                                          color: controller.isEditingMode.value ? Colors.white : Colors.grey.shade600,
                                        ),
                                        onPressed: () {
                                          controller.sendMessage(controller.inputController.text);
                                        },
                                      ),
                                    ).asGlass(clipBorderRadius: BorderRadius.circular(30));
                                  }),

                                  const SizedBox(width: 8),

                                  // Text Field
                                  Expanded(
                                    child: Container(
                                      constraints: const BoxConstraints(minHeight: 40, maxHeight: 100),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.grey.withValues(alpha: 0.05), // Adjusted from 0.2
                                            Colors.grey.withValues(alpha: 0.1), // Adjusted from 0.4
                                          ],
                                        ),
                                        border: Border.all(
                                          // Added back border
                                          color: Colors.grey.withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          // Added back boxShadow
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: controller.inputController,
                                        maxLines: null,
                                        // autofocus: true, // Removed to prevent loop
                                        textInputAction: TextInputAction.send,
                                        decoration: InputDecoration(
                                          hintText: 'نام محصول جدید را بنویسید...',
                                          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          suffixIcon: Obx(
                                            () => controller.hasInputText.value
                                                ? IconButton(
                                                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                                                    onPressed: () {
                                                      controller.inputController.clear();
                                                    },
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ),
                                        focusNode: controller.fc,
                                        textDirection: TextDirection.rtl,
                                        keyboardType: TextInputType.text,
                                        style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.65),
                                        onSubmitted: (_) {
                                          controller.sendMessage(controller.inputController.text);
                                          controller.fc.requestFocus();
                                        },
                                      ),
                                    ).asGlass(clipBorderRadius: BorderRadius.circular(30)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
    );
  }

  String _getStageSummary(Step2ChatController controller) {
    if (controller.currentStage.value == ChatStage.debts) {
      return 'بدهی‌ها: ${controller.debts.length} مورد';
    } else if (controller.currentStage.value == ChatStage.claims) {
      return 'طلب‌ها: ${controller.claims.length} مورد';
    } else if (controller.currentStage.value == ChatStage.cashCapital) {
      int total = 0;
      for (var item in controller.cashCapital) {
        total += int.tryParse(item['data']!) ?? 0;
      }
      return 'سرمایه: ${Price.showWithCurrency(total)}';
    } else if (controller.currentStage.value == ChatStage.confirmation) {
      return 'تایید نهایی';
    } else {
      return 'اتمام';
    }
  }
}

Widget buildStep2ChatRoute(RouteSettings settings) => Step2ChatScreen();
