import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mik_utils/public/startup.dart';

void main() {
  test(
    'startup repairs a missing user image directory and retains product files',
    () async {
      final directory = await Directory.systemTemp.createTemp('mik-startup-');
      addTearDown(() => directory.delete(recursive: true));
      final product = File('${directory.path}/img/product/retained.png');
      await product.parent.create(recursive: true);
      await product.writeAsString('retained');
      final paths = await StartupFX.directories(() async => directory);
      expect(await paths!.products.exists(), isTrue);
      expect(await paths.users.exists(), isTrue);
      expect(await product.readAsString(), 'retained');
      await StartupFX.directories(() async => directory);
      expect(await product.readAsString(), 'retained');
    },
  );

  test('startup ignores its own routes while retaining deep link queries', () {
    for (final path in [null, '', '/', '/splash', '/SplashScreen', '/?tab=1']) {
      expect(StartupFX.initialRoute(path), isNull);
    }
    expect(StartupFX.initialRoute('/invoice?tab=buy'), '/invoice?tab=buy');
    for (final url in [
      'https://app.example/invoice?tab=buy',
      'https://app.example/#/invoice?tab=buy',
    ]) {
      expect(StartupFX.browserRoute(Uri.parse(url)), '/invoice?tab=buy');
    }
    expect(StartupFX.browserRoute(Uri.parse('https://app.example/#/')), isNull);
  });
}
