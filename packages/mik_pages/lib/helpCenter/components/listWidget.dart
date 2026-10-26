import 'package:flutter/material.dart';
import 'package:mik_pages/helpCenter/components/textBuilder.dart';

class ListWidget extends StatelessWidget {
  final Map node;

  const ListWidget(this.node, {super.key});

  @override
  Widget build(BuildContext context) {
    final List items = node['children'] ?? [];

    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map<Widget>((item) {
        final List children = item['children'] ?? [];

        // هر text node → TextSpan
        final spans = children.where((c) => c['type'] == 'text').map<TextSpan>((c) => buildTextSpan(c)).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("• ", style: TextStyle(fontSize: 16)),
              Expanded(
                child: RichText(
                  textDirection: TextDirection.rtl,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black),
                    children: spans,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
