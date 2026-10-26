import 'package:flutter/material.dart';
import 'package:mik_pages/helpCenter/components/textBuilder.dart';

class ParagraphWidget extends StatelessWidget {
  final node;

  const ParagraphWidget(this.node, {super.key});

  @override
  Widget build(BuildContext context) {
    final List children = node['children'] ?? [];

    if (children.isEmpty) {
      return const SizedBox(height: 8);
    }

    final spans = children.where((c) => true).map<TextSpan>((c) => buildTextSpan(c)).toList();

    if (spans.isEmpty) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        textAlign: TextAlign.justify,
        text: TextSpan(style: const TextStyle(fontSize: 15, height: 1.6), children: spans),
      ),
    );
  }
}
