import 'package:get/get.dart';

class HelpMediaController extends GetxController {
  final Future<String> Function() readUrl;
  HelpMediaController(this.readUrl);
  String? url;
  Object? error;
  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final result = await readUrl();
      if (isClosed) return;
      url = result;
    } catch (failure) {
      if (isClosed) return;
      error = failure;
    }
    update();
  }
}
