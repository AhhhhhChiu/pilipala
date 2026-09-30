import 'package:flutter/material.dart';

/// 空降片段类别跳过模式
enum SbCategoryMode {
  /// 自动跳过
  auto,

  /// 显示提示条，手动确认跳过
  notice,

  /// 关闭
  off,
}

extension SbCategoryModeDesc on SbCategoryMode {
  String get desc {
    switch (this) {
      case SbCategoryMode.auto:
        return '自动跳过';
      case SbCategoryMode.notice:
        return '显示提示';
      case SbCategoryMode.off:
        return '关闭';
    }
  }
}

/// 片段类别定义
class SbCategory {
  final String key;
  final String label;
  final Color color;

  /// 默认跳过模式
  final SbCategoryMode defaultMode;
  const SbCategory(this.key, this.label, this.color, this.defaultMode);
}

class SbCategories {
  static const List<SbCategory> all = [
    SbCategory('sponsor', '恰饭片段', Color(0xFF00D464), SbCategoryMode.auto),
    SbCategory('selfpromo', '自我推广', Color(0xFFF9FF00), SbCategoryMode.notice),
    SbCategory('interaction', '三连提醒', Color(0xFFCC7700), SbCategoryMode.notice),
    SbCategory('poi_highlight', '精彩时刻', Color(0xFFFF1683), SbCategoryMode.notice),
    SbCategory('intro', '过场动画', Color(0xFF00FFFF), SbCategoryMode.notice),
    SbCategory('padding', '头尾填充', Color(0xFF606060), SbCategoryMode.notice),
    SbCategory('exclusive_access', '独家内容', Color(0xFF00B5A8), SbCategoryMode.off),
    SbCategory('outro', '结尾内容', Color(0xFF0202ED), SbCategoryMode.off),
    SbCategory('preview', '内容回顾', Color(0xFF008FD6), SbCategoryMode.off),
    SbCategory('filler', '离题闲聊', Color(0xFF7300FF), SbCategoryMode.off),
    SbCategory('music_offtopic', '非音乐部分', Color(0xFFFF9900), SbCategoryMode.off),
    SbCategory('ap_naier', 'AP纳尔', Color(0xFFEE7AE9), SbCategoryMode.off),
  ];

  static SbCategory? find(String? key) {
    for (final c in all) {
      if (c.key == key) {
        return c;
      }
    }
    return null;
  }

  /// 读取某类别当前生效的模式
  static SbCategoryMode modeOf(Map<String, dynamic> config, String? key) {
    final c = find(key);
    if (c == null) {
      return SbCategoryMode.off;
    }
    final v = config[key];
    if (v is int && v >= 0 && v < SbCategoryMode.values.length) {
      return SbCategoryMode.values[v];
    }
    return c.defaultMode;
  }
}

/// 空降片段（来自 bsbsb.top 服务端）
class SbSegment {
  final String uuid;
  final String category;
  final String actionType; // skip / mute / poi / full
  final double start;
  final double end;
  final int? cid;
  final double? videoDuration;
  final int? locked;

  const SbSegment({
    required this.uuid,
    required this.category,
    required this.actionType,
    required this.start,
    required this.end,
    this.cid,
    this.videoDuration,
    this.locked,
  });

  factory SbSegment.fromJson(Map<String, dynamic> json) {
    final seg = (json['segment'] as List?) ?? const [];
    return SbSegment(
      uuid: json['UUID']?.toString() ?? '',
      category: json['category']?.toString() ?? 'sponsor',
      actionType: json['actionType']?.toString() ?? 'skip',
      start: seg.isNotEmpty ? (seg[0] as num).toDouble() : 0.0,
      end: seg.length > 1 ? (seg[1] as num).toDouble() : 0.0,
      cid: json['cid'] != null ? int.tryParse(json['cid'].toString()) : null,
      videoDuration: json['videoDuration'] != null
          ? double.tryParse(json['videoDuration'].toString())
          : null,
      locked: json['locked'] != null ? int.tryParse(json['locked'].toString()) : null,
    );
  }
}

/// 跳过提示条状态
class SbNotice {
  final SbSegment segment;

  /// true: 已自动跳过，可撤销；false: 手动模式，展示跳过按钮
  final bool canUndo;
  const SbNotice(this.segment, this.canUndo);
}
