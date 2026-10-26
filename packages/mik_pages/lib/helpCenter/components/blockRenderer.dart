import 'package:get/get.dart';
import 'package:mik_pages/helpCenter/media_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mik_components/base/asyncWidget.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/helpCenterAPI.dart';
import 'package:mik_pages/helpCenter/components/audioPlayer.dart';
import 'package:mik_pages/helpCenter/components/videoPlayer.dart';
import 'package:url_launcher/url_launcher.dart';

// Widget BlockRenderer(Map fields) {
//   // return Container();
//   switch (fields['blockType']) {
//     case 'mediaBlock':
//       return MediaBlockWidget(fields['media']);

//     case 'galleryBlock':
//       return GalleryBlockWidget(fields['items']);

//     case 'ctaBlock':
//       return CtaBlockWidget(fields);

//     default:
//       return const SizedBox.shrink();
//   }
// }
import 'package:mik_pages/helpCenter/components/bannerWidget.dart';

class BlockRenderer extends StatelessWidget {
  final Map fields;

  const BlockRenderer(this.fields, {super.key});

  @override
  Widget build(BuildContext context) {
    final type = fields['blockType'] ?? '';
    switch (type) {
      case 'mediaBlock':
        return buildMediaBlock(fields['media']);

      case 'banner':
        return BannerWidget(fields: fields);

      default:
        return const SizedBox.shrink();
    }
  }
}

Widget buildMediaBlock(String mediaId) {
  return GetBuilder<HelpMediaController>(
    init: HelpMediaController(() => getMediaUrl(mediaId)),
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (c) {
      if (c.url == null) return const SizedBox(height: 150);
      final url = c.url!;
      if (url.endsWith('.mp4') || url.endsWith('.mov')) {
        return VideoPlayerWidget(url: url);
      } else if (url.endsWith('.mp3') || url.endsWith('.wav')) {
        return AudioPlayerWidget(url: url);
      } else {
        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: mediaId,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
    },
  );
}

class MediaBlockWidget extends StatelessWidget {
  final String mediaId;

  const MediaBlockWidget(this.mediaId, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: AsyncWidget(
        loadingDuration: 1000,
        initState: () => getMediaUrl(mediaId),
        child: (d) {
          return d == null || d == ''
              ? Image.asset(
                  'assets/images/logo/logow.png',
                  color: AppColors.primary,
                )
              : CachedNetworkImage(
                  imageUrl: d!,
                  cacheKey: mediaId,
                  fit: BoxFit.cover,
                  width: 200,
                );
        },
      ),
    );
  }
}

class GalleryBlockWidget extends StatelessWidget {
  final List<dynamic> items;

  const GalleryBlockWidget(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200, // ارتفاع گالری
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final mediaId = items[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AsyncWidget(
              loadingDuration: 1000,
              initState: () => getMediaUrl(mediaId),
              child: (d) {
                return d == null || d == ''
                    ? Image.asset(
                        'assets/images/logo/logow.png',
                        color: AppColors.primary,
                      )
                    : CachedNetworkImage(
                        imageUrl: d!,
                        cacheKey: mediaId,
                        fit: BoxFit.cover,
                        width: 200,
                      );
              },
            ),
          );
        },
      ),
    );
  }
}

class CtaBlockWidget extends StatelessWidget {
  final Map<dynamic, dynamic> fields;

  const CtaBlockWidget(this.fields, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fields['title'] ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if ((fields['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                fields['description'],
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              final url = fields['buttonUrl'];
              if (url != null) launchUrl(Uri.parse(url));
            },
            child: Text(fields['buttonText'] ?? 'Click'),
          ),
        ],
      ),
    );
  }
}

Future<String> getMediaUrl(String mediaId, {String? mediaUrl}) async {
  if (mediaUrl != null && mediaUrl != '') return mediaUrl;
  if (mediaId == '') return '';
  var d = await HelpCenterAPI.getMedia(mediaId);
  return d;
}
