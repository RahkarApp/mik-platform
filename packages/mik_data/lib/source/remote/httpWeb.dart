import 'debug_http_client.dart';
import 'package:http/http.dart' as http;

class HTTP {
  static io() {
    //final v = http.Client();
    return DebugHttpClient(http.Client());
  }
}
