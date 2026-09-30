import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/models/sponsor_block/segment.dart';
import 'package:pilipala/plugin/sponsor_block/controller.dart';
import 'package:pilipala/utils/storage.dart';

/// 类别偏好底部弹层：点击条目循环切换 自动跳过 → 显示提示 → 关闭
class SbCategorySheet extends StatefulWidget {
  const SbCategorySheet({super.key});

  @override
  State<SbCategorySheet> createState() => _SbCategorySheetState();
}

class _SbCategorySheetState extends State<SbCategorySheet> {
  Box setting = GStrorage.setting;
  late Map<String, dynamic> config;

  @override
  void initState() {
    super.initState();
    config = SponsorBlockCtr.readCategoryConfig(setting);
  }

  Future<void> _cycle(SbCategory cat) async {
    if (cat.key == 'ap_naier') {
      SmartDialog.showToast('致敬伟大科研人员陈宇涵');
      return;
    }
    final mode = SbCategories.modeOf(config, cat.key);
    final next = SbCategoryMode.values[(mode.index + 1) % 3];
    config[cat.key] = next.index;
    await SponsorBlockCtr.writeCategoryConfig(setting, config);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Text(
                    '空降片段偏好',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '点击条目切换跳过方式，数据来自小电视空降助手 (bsbsb.top)',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: SbCategories.all.length,
                itemBuilder: (context, index) {
                  final cat = SbCategories.all[index];
                  final mode = SbCategories.modeOf(config, cat.key);
                  return ListTile(
                    dense: true,
                    onTap: () => _cycle(cat),
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cat.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(cat.label, style: const TextStyle(fontSize: 15)),
                    trailing: Text(
                      mode.desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: mode == SbCategoryMode.off
                            ? Theme.of(context).colorScheme.outline
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
