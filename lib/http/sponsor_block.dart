import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pilipala/models/sponsor_block/segment.dart';

/// 小电视空降助手 (bsbsb.top) API
/// 协议文档: https://github.com/hanydd/BilibiliSponsorBlock/wiki/API
class SponsorBlockHttp {
  static const String baseUrl = 'https://www.bsbsb.top';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'x-ext-version': 'pilipala-sb-1.0'},
    ),
  );

  /// 通过 bvid 的 sha256 前 4 位拉取片段（隐私模式），本地按 videoID+cid 过滤
  static Future<List<SbSegment>> querySkipSegments({
    required String bvid,
    required int cid,
    required List<String> categories,
  }) async {
    final digest = sha256.convert(utf8.encode(bvid)).toString();
    final prefix = digest.substring(0, 4);
    try {
      final res = await _dio.get(
        '/api/skipSegments/$prefix',
        queryParameters: {
          'categories': jsonEncode(categories),
        },
      );
      final List list =
          res.data is String ? jsonDecode(res.data) as List : res.data as List;
      final List<SbSegment> result = [];
      for (final item in list) {
        if (item['videoID'] != bvid) {
          continue;
        }
        for (final seg in (item['segments'] ?? [])) {
          final s = SbSegment.fromJson(seg);
          // cid 严格匹配；缺失 cid 的旧数据宽容接受
          if (s.cid != null && s.cid != cid) {
            continue;
          }
          result.add(s);
        }
      }
      return result;
    } on DioException catch (e) {
      // 404 = 该视频暂无片段，属正常情况；其余网络问题静默降级
      if (e.response?.statusCode != 404) {
        // ignore: avoid_print
        print('SponsorBlock request failed: ${e.message}');
      }
      return [];
    } catch (err) {
      return [];
    }
  }
}
