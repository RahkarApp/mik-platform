enum ChatStage {
  debts, // بدهی ها
  claims, // طلب ها
  cashCapital, // سرمایه نقدی
  confirmation, // تایید نهایی
  finished, // پایان
}

class ChatMessage {
  String text;
  final bool isUser;
  final bool isDuplicate;
  final bool isTyping;
  int? productIndex; // اینکس محصول برای پیام‌های تایید
  bool isDeleteConfirmation; // آیا این پیام تاییدیه حذف است
  String? deletingProductName; // نام محصول برای حذف
  bool isPendingConfirmation; // آیا این پیام تایید محصولات ثابت شده است
  bool isDeleteAllConfirmation; // آیا این پیام تاییدیه حذف همه است
  bool isSystemMessage; // آیا این پیام عادی سیستم است (دیزاین یکسان)
  bool isWelcomeMessage; // آیا این پیام استقبالی است (برای نمایش دکمه)
  ChatStage? stage;
  int? listIndex;
  String? originalText; // The raw input (e.g. "Ali 1000")
  String? uuid; // Unique identifier for this item

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isDuplicate = false,
    this.isTyping = false,
    this.stage,
    this.listIndex,
    this.originalText,
    this.uuid,
    this.productIndex,
    this.isDeleteConfirmation = false,
    this.deletingProductName,
    this.isPendingConfirmation = false,
    this.isDeleteAllConfirmation = false,
    this.isSystemMessage = false,
    this.isWelcomeMessage = false,
  });
}
