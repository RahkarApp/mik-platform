import 'debug_http_client.dart';
import 'dart:io';

import 'package:http/io_client.dart';

class HTTP extends IOClient {
  static io() {
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return DebugHttpClient(IOClient(ioc));
  }
}
