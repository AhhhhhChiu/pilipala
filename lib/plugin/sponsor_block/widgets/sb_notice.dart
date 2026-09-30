import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/sponsor_block/segment.dart';
import 'package:pilipala/plugin/pl_player/index.dart';
import 'package:pilipala/plugin/sponsor_block/controller.dart';

String _fmtTime(double sec) {
  final s = sec.round();
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// 跳过提示条：自动跳过时提供撤销，手动模式时提供跳过按钮
class SbSkipNotice extends StatelessWidget {
  final PlPlayerController? controller;
  const SbSkipNotice({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctr = SponsorBlockCtr.i;
      final n = ctr.notice.value;
      final visible = n != null;
      return IgnorePointer(
        ignoring: !visible,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 96),
            child: AnimatedOpacity(
              curve: Curves.easeInOut,
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: n == null
                  ? const SizedBox.shrink()
                  : _buildPill(context, n),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPill(BuildContext context, SbNotice n) {
    final cat = SbCategories.find(n.segment.category);
    final label = cat?.label ?? n.segment.category;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xC8000000),
        borderRadius: BorderRadius.circular(64.0),
      ),
      height: 34.0,
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cat?.color ?? Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            n.canUndo ? '已跳过 $label' : label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (n.canUndo) ...[
            const SizedBox(width: 4),
            _actionBtn('撤销', ctrUndo: true),
            _actionBtn('✕', ctrUndo: false, dismiss: true),
          ] else
            ...[
              const SizedBox(width: 4),
              _actionBtn('跳过', ctrUndo: false),
            ],
        ],
      ),
    );
  }

  Widget _actionBtn(String text,
      {required bool ctrUndo, bool dismiss = false}) {
    return InkWell(
      onTap: () {
        final ctr = SponsorBlockCtr.i;
        if (dismiss) {
          ctr.dismissNotice();
        } else if (ctrUndo) {
          ctr.undoSkip();
        } else {
          ctr.manualSkip();
        }
      },
      borderRadius: BorderRadius.circular(64.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(Get.context!).colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 空降落点 pill：点击跳至精彩时刻
class SbPoiPill extends StatelessWidget {
  final PlPlayerController? controller;
  const SbPoiPill({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctr = SponsorBlockCtr.i;
      final poi = ctr.poiPill.value;
      if (poi == null) {
        return const SizedBox.shrink();
      }
      final posMs =
          (controller?.position.value ?? Duration.zero).inMilliseconds;
      if (posMs > poi.end * 1000) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 14, bottom: 96),
          child: GestureDetector(
            onTap: ctr.seekToPoi,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xC8000000),
                borderRadius: BorderRadius.circular(64.0),
              ),
              height: 34.0,
              padding: const EdgeInsets.only(left: 12, right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flight_takeoff,
                    size: 15,
                    color: SbCategories.find(poi.category)?.color ?? Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '空降 ${_fmtTime(poi.start)}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
