import 'package:flutter/material.dart';

class HeadingWidget extends StatelessWidget {
  final Map node;

  const HeadingWidget(this.node, {super.key});

  @override
  Widget build(BuildContext context) {
    final level = node['tag'] ?? 'h2';
    final size = {'h1': 26.0, 'h2': 22.0, 'h3': 18.0}[level]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        node['children'][0]['text'],
        style: TextStyle(fontSize: size, fontWeight: FontWeight.bold),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
