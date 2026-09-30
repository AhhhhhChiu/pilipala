import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/http/sponsor_block.dart';
import 'package:pilipala/models/sponsor_block/segment.dart';
import 'package:pilipala/plugin/pl_player/index.dart';
import 'package:pilipala/utils/storage.dart';

/// 空降助手控制器（单例、纯消费端）
/// 负责拉取片段、自动跳过调度、提示条状态管理
class SponsorBlockCtr {
  SponsorBlockCtr._();
  static final SponsorBlockCtr i = SponsorBlockCtr._();

  final Box _setting = GStrorage.setting;
  PlPlayerController? _player;

  /// 当前视频的片段
  final RxList<SbSegment> segments = <SbSegment>[].obs;

  /// 跳过提示条
  final Rxn<SbNotice> notice = Rxn<SbNotice>();

  /// 空降落点（精彩时刻 pill）
  final Rxn<SbSegment> poiPill = Rxn<SbSegment>();

  String _bvid = '';
  int _cid = 0;
  bool _enabled = false;
  Map<String, dynamic> _categoryConfig = {};
  final Set<String> _skipped = {};
  final Set<String> _undoForever = {};
  Timer? _noticeTimer;

  /// 挂载播放器，注册位置监听
  void attach(PlPlayerController player) {
    if (identical(_player, player)) {
      return;
    }
    _player?.removePositionListener(_onPosition);
    _player = player;
    player.addPositionListener(_onPosition);
  }

  /// 视频加载（playerInit 时调用），异步拉取片段
  void onVideoLoad({
    required String bvid,
    required int cid,
    required int durationSec,
  }) {
    _reset();
    _bvid = bvid;
    _cid = cid;
    _enabled = _setting.get(SettingBoxKey.sponsorBlockEnable, defaultValue: true) &&
        bvid.startsWith('BV');
    if (!_enabled) {
      return;
    }
    _categoryConfig = _readCategoryConfig();
    final enabledCategories = SbCategories.all
        .where((c) =>
            SbCategories.modeOf(_categoryConfig, c.key) != SbCategoryMode.off)
        .map((c) => c.key)
        .toList();
    if (enabledCategories.isEmpty) {
      return;
    }
    _load(enabledCategories, durationSec);
  }

  Future<void> _load(List<String> categories, int durationSec) async {
    final list = await SponsorBlockHttp.querySkipSegments(
      bvid: _bvid,
      cid: _cid,
      categories: categories,
    );
    if (list.isEmpty) {
      return;
    }
    // 按时长校验过滤（±5s），避免多版本视频数据错配
    List<SbSegment> filtered = list;
    if (durationSec > 0) {
      final matched = list
          .where((s) =>
              s.videoDuration == null ||
              (s.videoDuration! - durationSec).abs() <= 5)
          .toList();
      if (matched.isNotEmpty) {
        filtered = matched;
      }
    }
    segments.assignAll(filtered);
    // 取第一个精彩时刻作为空降落点
    for (final s in filtered) {
      if (s.actionType == 'poi' &&
          SbCategories.modeOf(_categoryConfig, s.category) !=
              SbCategoryMode.off) {
        poiPill.value = s;
        break;
      }
    }
  }

  void _reset() {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    segments.clear();
    notice.value = null;
    poiPill.value = null;
    _skipped.clear();
    _undoForever.clear();
  }

  Map<String, dynamic> _readCategoryConfig() {
    final raw = _setting.get(SettingBoxKey.sponsorBlockCategoryConfig);
    if (raw is String) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  static Map<String, dynamic> readCategoryConfig(Box setting) {
    final raw = setting.get(SettingBoxKey.sponsorBlockCategoryConfig);
    if (raw is String) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  static Future<void> writeCategoryConfig(
      Box setting, Map<String, dynamic> config) {
    return setting.put(
        SettingBoxKey.sponsorBlockCategoryConfig, jsonEncode(config));
  }

  SbCategoryMode _modeOf(SbSegment s) =>
      SbCategories.modeOf(_categoryConfig, s.category);

  /// 播放位置回调：跳过调度核心
  void _onPosition(Duration position) {
    final player = _player;
    if (player == null || !_enabled || segments.isEmpty) {
      return;
    }
    // 用户拖动进度条时不干预
    if (player.isSliderMoving.value) {
      return;
    }
    final t = position.inMilliseconds / 1000.0;

    final seg = _findSegment(t);

    // 手动提示条：离开片段时隐藏
    final cur = notice.value;
    if (cur != null && !cur.canUndo && seg?.uuid != cur.segment.uuid) {
      notice.value = null;
    }

    if (seg == null) {
      return;
    }
    if (_undoForever.contains(seg.uuid)) {
      return;
    }
    switch (_modeOf(seg)) {
      case SbCategoryMode.off:
        break;
      case SbCategoryMode.auto:
        if (!_skipped.contains(seg.uuid)) {
          _autoSkip(seg, player, t);
        }
        break;
      case SbCategoryMode.notice:
        if (cur == null || cur.segment.uuid != seg.uuid) {
          notice.value = SbNotice(seg, false);
        }
        break;
    }
  }

  /// 查找当前位置所处的可跳过片段
  SbSegment? _findSegment(double t) {
    for (final s in segments) {
      if (s.actionType != 'skip') {
        continue;
      }
      if (_modeOf(s) == SbCategoryMode.off) {
        continue;
      }
      if (t >= s.start && t < s.end) {
        return s;
      }
    }
    return null;
  }

  /// 自动跳过：合并相交的自动跳过片段，一次性跳到链尾
  void _autoSkip(SbSegment seg, PlPlayerController player, double t) {
    double end = seg.end;
    bool extended = true;
    while (extended) {
      extended = false;
      for (final s in segments) {
        if (s.actionType != 'skip' ||
            _modeOf(s) != SbCategoryMode.auto ||
            _undoForever.contains(s.uuid)) {
          continue;
        }
        if (s.start <= end && s.end > end) {
          end = s.end;
          extended = true;
        }
      }
    }
    final durationSec = player.duration.value.inMilliseconds / 1000.0;
    if (durationSec > 0 && end > durationSec - 0.1) {
      end = durationSec - 0.1;
    }
    _skipped.add(seg.uuid);
    notice.value = SbNotice(seg, true);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 8), () {
      if (notice.value?.canUndo == true) {
        notice.value = null;
      }
    });
    player.seekTo(Duration(milliseconds: (end * 1000).round()));
  }

  /// 撤销跳过：回到片段开头，且本视频内不再自动跳过
  void undoSkip() {
    final seg = notice.value?.segment;
    if (seg == null) {
      return;
    }
    _noticeTimer?.cancel();
    _undoForever.add(seg.uuid);
    _skipped.remove(seg.uuid);
    notice.value = null;
    _player?.seekTo(Duration(milliseconds: (seg.start * 1000).round()));
  }

  /// 手动模式：确认跳过
  void manualSkip() {
    final seg = notice.value?.segment;
    if (seg == null) {
      return;
    }
    _skipped.add(seg.uuid);
    notice.value = null;
    _player?.seekTo(Duration(milliseconds: (seg.end * 1000).round()));
  }

  /// 关闭提示条
  void dismissNotice() {
    _noticeTimer?.cancel();
    final seg = notice.value?.segment;
    if (seg != null && !notice.value!.canUndo) {
      _undoForever.add(seg.uuid);
    }
    notice.value = null;
  }

  /// 空降至精彩时刻
  void seekToPoi() {
    final s = poiPill.value;
    if (s == null) {
      return;
    }
    poiPill.value = null;
    _player?.seekTo(Duration(milliseconds: (s.start * 1000).round()));
  }

  void detach() {
    _player?.removePositionListener(_onPosition);
    _player = null;
    _reset();
  }
}
