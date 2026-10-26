import 'package:permission_handler/permission_handler.dart';

class PermissionHandler {
  static storage() async {
    var status = await Permission.storage.status;
    if (status.isDenied) {
      await Permission.storage.request();
    }
    var writeStatus = await Permission.manageExternalStorage.status;
    if (writeStatus.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  static camera() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      await Permission.camera.request();
    }
  }
}
