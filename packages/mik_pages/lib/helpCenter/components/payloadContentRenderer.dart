import 'package:flutter/material.dart';
import 'package:mik_pages/helpCenter/components/blockRenderer.dart';
import 'package:mik_pages/helpCenter/components/headingWidget.dart';
import 'package:mik_pages/helpCenter/components/listWidget.dart';
import 'package:mik_pages/helpCenter/components/paragraphWidget.dart';
import 'package:mik_pages/helpCenter/components/quoteWidget.dart';

class PayloadContentRenderer extends StatelessWidget {
  final Map<String, dynamic> content;

  const PayloadContentRenderer({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final children = content['root']['children'] as List;
    for (var i = 0; i < children.length; i++) {
      var r = children[i];
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children.map<Widget>((e) => e['children'] == [] ? Container() : renderNode(e)).toList());
  }
}

//  0: {children: [{detail: 0, format: 0, mode: normal, style: , text: تست مرکز آموزش/آموزش, type: text, version: 1}], direction: null, format: , indent: 0, type: paragraph, version: 1, textFormat: 0, textStyle: }
//  1: {children: [], direction: null, format: , indent: 0, type: paragraph, version: 1, textFormat: 0, textStyle: }
//  2: {type: block, version: 2, format: , fields: {id: 69883d5c69f7523f6c27f44c, media: 69883bbd5e32fd255a3afb0d, blockName: test, blockType: mediaBlock}}
//  3: {children: [{detail: 0, format: 0, mode: normal, style: , text: ادامه متن در پیام, type: text, version: 1}], direction: null, format: , indent: 0, type: paragraph, version: 1, textFormat: 0, textStyle: }
Widget renderNode(Map node) {
  switch (node['type']) {
    case 'paragraph':
      return ParagraphWidget(node);
    case 'heading':
      return HeadingWidget(node);

    case 'list':
      return ListWidget(node);

    case 'quote':
      return QuoteWidget(node);

    case 'block':
      return BlockRenderer(node['fields']);

    default:
      return const SizedBox.shrink();
  }
}
