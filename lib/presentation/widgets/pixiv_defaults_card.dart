import 'package:flutter/material.dart';

import '../../domain/entities/pixiv_upload_task.dart';

/// Default-value controls for the publish form, mirroring [PixivVisibilityCard]
/// but bound to [PixivSettings] defaults instead of a single task.
class PixivDefaultsCard extends StatelessWidget {
  const PixivDefaultsCard({
    super.key,
    required this.xRestrict,
    required this.aiType,
    required this.restrict,
    required this.allowComment,
    required this.original,
    required this.allowTagEdit,
    required this.stripMetadata,
    required this.suggestTagsEnabled,
    required this.onXRestrictChanged,
    required this.onAiTypeChanged,
    required this.onRestrictChanged,
    required this.onAllowCommentChanged,
    required this.onOriginalChanged,
    required this.onAllowTagEditChanged,
    required this.onStripMetadataChanged,
    required this.onSuggestTagsChanged,
  });

  final PixivXRestrict xRestrict;
  final PixivAiType aiType;
  final PixivRestrict restrict;
  final bool allowComment;
  final bool original;
  final bool allowTagEdit;
  final bool stripMetadata;
  final bool suggestTagsEnabled;

  final ValueChanged<PixivXRestrict> onXRestrictChanged;
  final ValueChanged<PixivAiType> onAiTypeChanged;
  final ValueChanged<PixivRestrict> onRestrictChanged;
  final ValueChanged<bool> onAllowCommentChanged;
  final ValueChanged<bool> onOriginalChanged;
  final ValueChanged<bool> onAllowTagEditChanged;
  final ValueChanged<bool> onStripMetadataChanged;
  final ValueChanged<bool> onSuggestTagsChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发布默认值', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<PixivXRestrict>(
              initialValue: xRestrict,
              decoration: const InputDecoration(
                labelText: '默认年龄限制',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PixivXRestrict.general,
                  child: Text('一般'),
                ),
                DropdownMenuItem(
                  value: PixivXRestrict.r18,
                  child: Text('R-18'),
                ),
                DropdownMenuItem(
                  value: PixivXRestrict.r18g,
                  child: Text('R-18G'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onXRestrictChanged(v);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PixivAiType>(
              initialValue: aiType,
              decoration: const InputDecoration(
                labelText: '默认 AI 生成声明',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PixivAiType.aiGenerated,
                  child: Text('AI 生成'),
                ),
                DropdownMenuItem(value: PixivAiType.human, child: Text('人类创作')),
              ],
              onChanged: (v) {
                if (v != null) onAiTypeChanged(v);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PixivRestrict>(
              initialValue: restrict,
              decoration: const InputDecoration(
                labelText: '默认可见范围',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PixivRestrict.public,
                  child: Text('向所有人公开'),
                ),
                DropdownMenuItem(
                  value: PixivRestrict.myFans,
                  child: Text('仅我的粉丝'),
                ),
                DropdownMenuItem(
                  value: PixivRestrict.myFriends,
                  child: Text('仅我的好友'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onRestrictChanged(v);
              },
            ),
            SwitchListTile(
              title: const Text('默认开启评论'),
              value: allowComment,
              onChanged: onAllowCommentChanged,
            ),
            SwitchListTile(
              title: const Text('默认原创声明'),
              value: original,
              onChanged: onOriginalChanged,
            ),
            SwitchListTile(
              title: const Text('允许他人编辑标签'),
              value: allowTagEdit,
              onChanged: onAllowTagEditChanged,
            ),
            SwitchListTile(
              title: const Text('剥离 NAI 元数据'),
              subtitle: const Text('移除 tEXt 块 + alpha LSB 清零'),
              value: stripMetadata,
              onChanged: onStripMetadataChanged,
            ),
            SwitchListTile(
              title: const Text('启用 Tag 建议'),
              value: suggestTagsEnabled,
              onChanged: onSuggestTagsChanged,
            ),
          ],
        ),
      ),
    );
  }
}
