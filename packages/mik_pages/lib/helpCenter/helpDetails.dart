import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_data/source/remote/helpCenterAPI.dart';
import 'package:mik_pages/helpCenter/components/payloadContentRenderer.dart';

class HelpDetailsPage extends StatelessWidget {
  final String postId;
  final String postName;
  final scrollController;
  final bool? header;
  const HelpDetailsPage({super.key, required this.postId, required this.postName, this.scrollController, this.header});

  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => await HelpCenterAPI.getHelp(postId),
      loadingDuration: 1000,
      header: header ?? true ? Header.page(context, text: postName, help: false) : null,
      child: (post) {
        if (post['data']['docs'].isNotEmpty) {
          final content = post['data']['docs'][0]['content'];
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: PayloadContentRenderer(content: content),
          );
        } else {
          return EmptyList(icon: IconsaxPlusLinear.document, text: 'متن آموزش یافت نشد!');
        }
      },
    );
  }
}
