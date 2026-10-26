import 'package:get/get.dart';

class ProfileImageController extends GetxController {
  final Future<Object?> Function() readPath;
  ProfileImageController(this.readPath);
  String? path;
  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final result = await readPath();
      if (isClosed) return;
      path = result is String ? result : null;
    } catch (_) {
      if (isClosed) return;
      path = null;
    }
    update();
  }
}
