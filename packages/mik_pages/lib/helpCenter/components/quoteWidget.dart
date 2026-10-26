import 'package:flutter/material.dart';

class QuoteWidget extends StatelessWidget {
  final Map node;

  const QuoteWidget(this.node, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(width: 4, color: Colors.grey.shade400)),
      ),
      child: Text(
        node['children'][0]['text'],
        style: const TextStyle(fontStyle: FontStyle.italic),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
