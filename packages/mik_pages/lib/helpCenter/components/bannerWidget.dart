import 'package:flutter/material.dart';
import 'package:mik_pages/helpCenter/components/payloadContentRenderer.dart';

class BannerWidget extends StatelessWidget {
  final fields;

  const BannerWidget({required this.fields, super.key});

  @override
  Widget build(BuildContext context) {
    final content = fields['content'] ?? {};
    final style = fields['style'] ?? 'info';

    Color backgroundColor;
    Color borderColor;

    switch (style) {
      case 'warning':
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        break;
      case 'error':
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        break;
      case 'success':
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        break;
      case 'info':
      default:
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: PayloadContentRenderer(content: content),
    );
  }
}
