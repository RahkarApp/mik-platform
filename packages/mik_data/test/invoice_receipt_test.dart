import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mik_data/utils/pdf/receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const line = ReceiptLine(
    name: 'کالای نمونه - رنگ آبی',
    amount: 2,
    price: 150000,
    vatPercent: 10,
  );
  ReceiptData receipt({int count = 2}) => ReceiptData(
    uid: 'test-invoice',
    number: '۱۲۳',
    seller: 'فروشگاه نمونه میک',
    customer: 'مشتری آزمایشی',
    date: '۱۴۰۵/۰۷/۲۸',
    lines: List.filled(count, line),
    adjustment: -20000,
    shipping: 5000,
    note: 'با سپاس از خرید شما\nاین فاکتور نمونه برای بررسی خروجی است.',
  );

  setUpAll(() async {
    final bytes = await File('../../mik-yar/assets/fonts/RaviLight.ttf')
        .readAsBytes();
    await (FontLoader(
      'ravi',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  test('totals use stored prices, quantities, adjustments and shipping', () {
    expect(receipt().subtotal, 600000);
    expect(receipt().total, 585000);
  });

  test('generates real PDF bytes', () async {
    final files = await ReceiptPDF.factorGenerate(
      receipt(count: 22),
      showVat: true,
    );
    expect(files.length, 1);
    expect(String.fromCharCodes(files.single.bytes.take(5)), '%PDF-');
    expect(files.single.mimeType, 'application/pdf');
    await File('/tmp/mik-invoice-preview.pdf').writeAsBytes(files.single.bytes);
  });

  test('long image receipts are paginated without dropping items', () async {
    final files = await ReceiptPDF.factorGenerate(
      receipt(count: 22),
      asImage: true,
      showVat: true,
    );
    expect(files.length, 3);
    expect(files.last.name, 'F-test-invoice-3.png');
    for (final file in files) {
      expect(file.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    }
    await File('/tmp/mik-invoice-preview.png').writeAsBytes(files.last.bytes);
  });

  test('landscape PDF and empty invoices produce valid files', () async {
    final files = await ReceiptPDF.factorGenerate(
      receipt(count: 0),
      landscape: true,
      showVat: true,
    );
    expect(files.single.bytes.length, greaterThan(1000));
    await File('/tmp/mik-invoice-landscape-preview.pdf')
        .writeAsBytes(files.single.bytes);
  });
}
