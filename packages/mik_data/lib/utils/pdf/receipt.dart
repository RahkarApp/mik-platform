import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptLine {
  final String name;
  final num amount;
  final num price;
  final num vatPercent;
  const ReceiptLine({
    required this.name,
    required this.amount,
    required this.price,
    this.vatPercent = 0,
  });
  num get total => amount * price;
}

class ReceiptData {
  final String uid, number, seller, customer, date, note;
  final List<ReceiptLine> lines;
  final num adjustment, shipping;
  const ReceiptData({
    required this.uid,
    required this.number,
    required this.seller,
    required this.customer,
    required this.date,
    required this.lines,
    this.note = '',
    this.adjustment = 0,
    this.shipping = 0,
  });
  num get subtotal => lines.fold<num>(0, (sum, line) => sum + line.total);
  num get total => subtotal + adjustment + shipping;
}

class ReceiptFile {
  final Uint8List bytes;
  final String name, mimeType;
  const ReceiptFile(this.bytes, this.name, this.mimeType);
}

/// Uses Flutter's Persian text shaping for both PDF pages and PNG receipts.
abstract final class ReceiptPDF {
  static Future<List<ReceiptFile>> factorGenerate(
    ReceiptData data, {
    bool asImage = false,
    bool landscape = false,
    bool isRial = false,
    bool showVat = false,
  }) async {
    final format = landscape && !asImage
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;
    final rowsPerPage = ((format.height - 365) / 44).floor();
    final pageCount = data.lines.isEmpty
        ? 1
        : (data.lines.length / rowsPerPage).ceil();
    final images = <Uint8List>[];
    for (var page = 0; page < pageCount; page++) {
      final start = page * rowsPerPage;
      final end = (start + rowsPerPage).clamp(0, data.lines.length);
      images.add(
        await _page(
          data,
          format,
          data.lines.sublist(start, end),
          start,
          page,
          pageCount,
          isRial,
          showVat,
        ),
      );
    }
    final identifier = data.uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (asImage) {
      return [
        for (var i = 0; i < images.length; i++)
          ReceiptFile(images[i], 'F-$identifier-${i + 1}.png', 'image/png'),
      ];
    }
    final document = pw.Document(
      title: 'Invoice ${data.number}',
      author: data.seller,
    );
    for (final image in images) {
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(image), fit: pw.BoxFit.fill),
        ),
      );
    }
    return [
      ReceiptFile(
        await document.save(),
        'F-$identifier.pdf',
        'application/pdf',
      ),
    ];
  }

  static Future<Uint8List> _page(
    ReceiptData data,
    PdfPageFormat format,
    List<ReceiptLine> lines,
    int start,
    int page,
    int pages,
    bool isRial,
    bool showVat,
  ) async {
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    final width = format.width;
    final height = format.height;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..color = const ui.Color(0xffffffff),
    );
    void text(
      String value,
      double x,
      double y,
      double w, {
      double size = 11,
      bool bold = false,
      int maxLines = 2,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'ravi',
            fontFamilyFallback: const ['negar', 'sans-serif'],
            fontSize: size,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: const ui.Color(0xff252525),
          ),
        ),
        textDirection: ui.TextDirection.rtl,
        textAlign: TextAlign.right,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(minWidth: w, maxWidth: w);
      painter.paint(canvas, ui.Offset(x, y));
    }

    String amount(num value) {
      final number = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
      return number.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
    }

    String money(num value) => amount(value * (isRial ? 10 : 1));
    const margin = 28.0;
    final contentWidth = width - margin * 2;
    final currency = isRial ? 'ریال' : 'تومان';
    text(
      data.seller,
      margin,
      25,
      contentWidth,
      size: 18,
      bold: true,
      maxLines: 1,
    );
    text(
      'فاکتور شماره ${data.number}',
      margin,
      57,
      contentWidth,
      size: 14,
      bold: true,
    );
    text('طرف حساب: ${data.customer}', margin, 86, contentWidth);
    text(
      'تاریخ: ${data.date}    |    واحد قیمت: $currency',
      margin,
      112,
      contentWidth,
    );
    final widths = [
      contentWidth * .23,
      contentWidth * .20,
      contentWidth * .13,
      contentWidth * .44,
    ];
    var y = 149.0;
    canvas.drawRect(
      ui.Rect.fromLTWH(margin, y - 5, contentWidth, 30),
      ui.Paint()..color = const ui.Color(0xffece8f4),
    );
    void row(List<String> cells, {bool bold = false}) {
      var x = margin;
      for (var i = 0; i < cells.length; i++) {
        text(cells[i], x + 5, y, widths[i] - 10, bold: bold);
        x += widths[i];
      }
    }

    row(['جمع', 'قیمت واحد', 'تعداد', 'شرح کالا / خدمت'], bold: true);
    y += 33;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      row([
        money(line.total),
        money(line.price),
        amount(line.amount),
        '${start + i + 1}. ${line.name}',
      ]);
      canvas.drawLine(
        ui.Offset(margin, y + 34),
        ui.Offset(width - margin, y + 34),
        ui.Paint()
          ..color = const ui.Color(0xffdddddd)
          ..strokeWidth = .5,
      );
      y += 44;
    }
    if (page == pages - 1) {
      y += 12;
      text(
        'جمع کالاها: ${money(data.subtotal)} $currency',
        margin,
        y,
        contentWidth,
      );
      y += 23;
      text(
        'تعدیلات: ${money(data.adjustment)}    هزینه ارسال: ${money(data.shipping)}',
        margin,
        y,
        contentWidth,
      );
      y += 23;
      if (showVat) {
        final tax = data.lines.fold<num>(
          0,
          (sum, line) =>
              sum + line.total * line.vatPercent / (100 + line.vatPercent),
        );
        text(
          'مالیات مستتر در قیمت‌ها: ${money(tax)} $currency',
          margin,
          y,
          contentWidth,
        );
        y += 23;
      }
      text(
        'مبلغ نهایی: ${money(data.total)} $currency',
        margin,
        y,
        contentWidth,
        size: 14,
        bold: true,
      );
      if (data.note.isNotEmpty) {
        text(data.note, margin, y + 30, contentWidth, size: 10);
      }
    }
    text(
      'صفحه ${page + 1} از $pages',
      margin,
      height - 30,
      contentWidth,
      size: 9,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * scale).ceil(),
      (height * scale).ceil(),
    );
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Receipt image could not be encoded.');
      }
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}
