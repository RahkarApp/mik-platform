import 'package:mik_components/base/alert.dart';
import 'package:mik_data/utils/variable.dart';

class ProfileHelper {
  static check() async {
    if (profile.isNotEmpty) {
      var pr = profile.getAt(0)!;
      try {
        if (pr.name != null) {
          if (pr.type == null || pr.type == []) {
            pr.type = ['product'];
            await profile.putAt(0, pr);
          }
          return true;
        } else {
          Alert.error('مجددا وارد شوید!');
          return false;
        }
      } catch (e) {
        Alert.error('مجددا وارد شوید!');
        return false;
      }
    } else {
      return false;
    }
  }
}
