import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mik_variables/variable.dart';
import 'package:url_launcher/url_launcher.dart';

TextSpan buildTextSpan(Map<String, dynamic> node) {
  final format = node['format'] ?? 0;
  final String style = node['style'] ?? '';

  switch (node['type']) {
    case 'text':
      final String text = node['text'] ?? '';
      return TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ravi',
          fontWeight: format & 1 != 0 ? FontWeight.bold : FontWeight.normal,
          fontStyle: format & 2 != 0 ? FontStyle.italic : FontStyle.normal,
          decoration: _getTextDecoration(format),
          color: _extractColor(style),
        ),
      );

    case 'link':
      final String url = node['fields']?['url'] ?? '';
      final List children = node['children'] ?? [];

      // recursive تبدیل children لینک
      final List<TextSpan> linkSpans = children.map<TextSpan>((c) => buildTextSpan(c)).toList();
      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          if (url.isNotEmpty) {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          }
        };

      return TextSpan(
        children: linkSpans,
        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
        recognizer: recognizer,
      );

    case 'paragraph':
    case 'root':
      final List children = node['children'] ?? [];
      return TextSpan(children: children.map<TextSpan>((c) => buildTextSpan(c)).toList());

    default:
      return const TextSpan(text: '');
  }
}

TextDecoration? _getTextDecoration(int format) {
  List<TextDecoration> dec = [];
  if (format & 4 != 0) dec.add(TextDecoration.underline);
  if (format & 8 != 0) dec.add(TextDecoration.lineThrough);
  if (dec.isEmpty) return null;
  if (dec.length == 1) return dec.first;
  return TextDecoration.combine(dec);
}

Color? _extractColor(String style) {
  final regex = RegExp(r'color:\s*rgb\((\d+),\s*(\d+),\s*(\d+)\)');
  final match = regex.firstMatch(style);
  if (match == null) return darkMode.value ? Colors.white : Colors.black;
  return Color.fromARGB(255, int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
}
