import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/sponsor_block/segment.dart';
import 'package:pilipala/plugin/pl_player/index.dart';
import 'package:pilipala/plugin/sponsor_block/controller.dart';

/// 进度条上的空降片段色条覆盖层
/// 需与 ProgressBar (audio_video_progress_bar) 同尺寸放置于其上，
/// 内部绘制几何与该包 _drawBar 保持一致：
/// x = fraction * (width - barHeight) + barHeight / 2
class SbPreviewBar extends StatelessWidget {
  final PlPlayerController? controller;
  final double barHeight;
  const SbPreviewBar({super.key, this.controller, this.barHeight = 3.5});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final segments = SponsorBlockCtr.i.segments;
      final totalMs =
          (controller?.duration.value ?? Duration.zero).inMilliseconds;
      if (segments.isEmpty || totalMs <= 0) {
        return const SizedBox.shrink();
      }
      return IgnorePointer(
        child: CustomPaint(
          painter: SbBarPainter(
            segments.toList(),
            totalMs,
            barHeight,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

class SbBarPainter extends CustomPainter {
  final List<SbSegment> segments;
  final int totalMs;
  final double barHeight;
  SbBarPainter(this.segments, this.totalMs, this.barHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double w = size.width;
    final double adjusted = w - barHeight;
    final double y = h / 2;
    for (final s in segments) {
      // poi / full 类型不在进度条上绘制
      if (s.actionType != 'skip' && s.actionType != 'mute') {
        continue;
      }
      final cat = SbCategories.find(s.category);
      if (cat == null) {
        continue;
      }
      final double x1 =
          (s.start * 1000 / totalMs) * adjusted + barHeight / 2;
      final double x2 = (s.end * 1000 / totalMs) * adjusted + barHeight / 2;
      if (x2 - x1 < 0.1) {
        continue;
      }
      final paint = Paint()
        ..color = cat.color
        ..strokeWidth = barHeight
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
    }
  }

  @override
  bool shouldRepaint(SbBarPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.totalMs != totalMs ||
      oldDelegate.barHeight != barHeight;
}
