import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:mik_consts/colors.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({required this.url, super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetController extends GetxController {
  late VideoPlayerController _controller;
  bool videoReady = false;
  double speed = 1.0;
  final speeds = [0.5, 1.0, 1.5, 2.0];
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final _page = _VideoPlayerWidgetController();

  @override
  void initState() {
    super.initState();
    _page._controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..addListener(_onVideoUpdate)
      ..initialize().then((_) {
        {
          _page.videoReady = true;
          _page.update();
        }
      });
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    {
      _page.update();
    }
  }

  @override
  void dispose() {
    _page._controller.removeListener(_onVideoUpdate);
    _page._controller.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_VideoPlayerWidgetController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        if (!_page.videoReady) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: _page._controller.value.aspectRatio,
                  child: VideoPlayer(_page._controller),
                ),
              ),
              // 🔹 کنترل‌ها
              Row(
                children: [
                  // ⏩ سرعت
                  PopupMenuButton<double>(
                    initialValue: _page.speed,
                    onSelected: (v) {
                      _page.speed = v;
                      _page._controller.setPlaybackSpeed(v);
                      {
                        _page.update();
                      }
                    },
                    itemBuilder: (_) => _page.speeds
                        .map(
                          (e) => PopupMenuItem(value: e, child: Text('${e}x')),
                        )
                        .toList(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${_page.speed}x',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // ⏱ زمان
                  SizedBox(
                    width: 48,
                    child: Text(
                      _format(_page._controller.value.duration),
                      maxLines: 1,
                    ),
                  ),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2, // ضخامت نوار
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6, // اندازه دایره
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12, // هاله موقع لمس
                          ),
                          activeTrackColor: AppColors.primaryDark,
                          inactiveTrackColor: Colors.grey.shade400,
                        ),
                        child: Slider(
                          min: 0,
                          max: _page._controller.value.duration.inMilliseconds
                              .toDouble(),
                          value: _page._controller.value.position.inMilliseconds
                              .clamp(
                                0,
                                _page._controller.value.duration.inMilliseconds,
                              )
                              .toDouble(),
                          inactiveColor: AppColors.disable,
                          onChanged: (v) {
                            _page._controller.seekTo(
                              Duration(milliseconds: v.toInt()),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      _format(_page._controller.value.position),
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _page._controller.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                    onPressed: () {
                      {
                        _page._controller.value.isPlaying
                            ? _page._controller.pause()
                            : _page._controller.play();
                        _page.update();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
