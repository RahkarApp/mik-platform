import 'package:get/get.dart';

import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mik_consts/colors.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({required this.url, super.key});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetController extends GetxController {
  final AudioPlayer _player = AudioPlayer();
  bool playing = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double speed = 1.0;
  final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  late List<double> wave;
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final _page = _AudioPlayerWidgetController();

  @override
  void initState() {
    super.initState();
    _page.wave = generateWaveform(
      bars: 48,
      seed: widget.url, // هر فایل موج خاص خودش
    );
    _page._player.onDurationChanged.listen((d) {
      {
        _page.duration = d;
        _page.update();
      }
    });

    _page._player.onPositionChanged.listen((p) {
      {
        _page.position = p;
        _page.update();
      }
    });

    _page._player.onPlayerComplete.listen((_) {
      {
        _page.playing = false;
        _page.position = Duration.zero;
        _page.update();
      }
    });
  }

  @override
  void dispose() {
    _page._player.dispose();
    super.dispose();
  }

  Future<void> togglePlay() async {
    if (_page.playing) {
      await _page._player.pause();
    } else {
      await _page._player.play(UrlSource(widget.url));
      await _page._player.setPlaybackRate(_page.speed);
    }
    {
      _page.playing = !_page.playing;
      _page.update();
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_AudioPlayerWidgetController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// controls
                Row(
                  children: [
                    /// speed
                    PopupMenuButton<double>(
                      initialValue: _page.speed,
                      onSelected: (v) async {
                        _page.speed = v;
                        await _page._player.setPlaybackRate(_page.speed);
                        {
                          _page.update();
                        }
                      },
                      itemBuilder: (c) => _page.speeds
                          .map(
                            (s) =>
                                PopupMenuItem(value: s, child: Text('${s}x')),
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

                    /// time slider
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            final box = context.findRenderObject() as RenderBox;
                            final dx = d.localPosition.dx;
                            final percent = (dx / box.size.width).clamp(
                              0.0,
                              1.0,
                            );

                            final target = _page.duration * percent;

                            _page._player.seek(target);
                          },
                          onHorizontalDragUpdate: (d) {
                            final box = context.findRenderObject() as RenderBox;
                            final dx = d.localPosition.dx;
                            final percent = (dx / box.size.width).clamp(
                              0.0,
                              1.0,
                            );

                            final target = _page.duration * percent;

                            _page._player.seek(target);
                          },
                          child: SmartWaveform(
                            position: _page.position,
                            duration: _page.duration,
                            heights: _page.wave,
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      icon: Icon(
                        _page.playing ? Icons.pause_circle : Icons.play_circle,
                      ),
                      onPressed: togglePlay,
                    ),
                  ],
                ),

                /// time labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _format(_page.duration),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        _format(_page.position),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WaveBar extends StatelessWidget {
  final double height;
  final double progress; // 0..1

  const WaveBar({required this.height, required this.progress, super.key});

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      Colors.grey.shade400,
      AppColors.primary,
      progress,
    )!;

    return Container(
      width: 3,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

double barProgress(int index, int totalBars, double globalProgress) {
  final barStart = index / totalBars;
  final barEnd = (index + 1) / totalBars;

  if (globalProgress <= barStart) return 0.0;
  if (globalProgress >= barEnd) return 1.0;

  return (globalProgress - barStart) / (barEnd - barStart);
}

List<double> generateWaveform({required int bars, required String seed}) {
  final rand = Random(seed.hashCode);
  return List.generate(bars, (_) {
    return 6 + rand.nextDouble() * 22; // ارتفاع طبیعی
  });
}

class SmartWaveform extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final List<double> heights;

  const SmartWaveform({
    required this.position,
    required this.duration,
    required this.heights,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(heights.length, (i) {
        final p = barProgress(i, heights.length, progress);
        return WaveBar(height: heights[i], progress: p);
      }),
    );
  }
}
