import 'package:flutter/material.dart';

import '../../domain/entities/pixiv_upload_task.dart';

/// Age rating, AI declaration, visibility, comment, sexual, auto-accept and
/// original toggles — the "作品设置" card on the publish page.
class PixivVisibilityCard extends StatelessWidget {
  const PixivVisibilityCard({
    super.key,
    required this.xRestrict,
    required this.aiType,
    required this.restrict,
    required this.allowComment,
    required this.sexual,
    required this.responseAutoAccept,
    required this.original,
    required this.onXRestrictChanged,
    required this.onAiTypeChanged,
    required this.onRestrictChanged,
    required this.onAllowCommentChanged,
    required this.onSexualChanged,
    required this.onResponseAutoAcceptChanged,
    required this.onOriginalChanged,
  });

  final PixivXRestrict xRestrict;
  final PixivAiType aiType;
  final PixivRestrict restrict;
  final bool allowComment;
  final bool sexual;
  final bool responseAutoAccept;
  final bool original;

  final ValueChanged<PixivXRestrict> onXRestrictChanged;
  final ValueChanged<PixivAiType> onAiTypeChanged;
  final ValueChanged<PixivRestrict> onRestrictChanged;
  final ValueChanged<bool> onAllowCommentChanged;
  final ValueChanged<bool> onSexualChanged;
  final ValueChanged<bool> onResponseAutoAcceptChanged;
  final ValueChanged<bool> onOriginalChanged;

  @override
  Widget build(BuildContext context) {
    // sexual only meaningful for R-18/R-18G; Pixiv forces false otherwise,
    // so hide it for all-ages to avoid confusion.
    final showSexual = xRestrict != PixivXRestrict.general;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('作品设置', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<PixivXRestrict>(
              initialValue: xRestrict,
              decoration: const InputDecoration(
                labelText: '年龄限制',
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
                labelText: 'AI 生成作品',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PixivAiType.aiGenerated,
                  child: Text('是 (AI 生成)'),
                ),
                DropdownMenuItem(
                  value: PixivAiType.human,
                  child: Text('否 (人类创作)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onAiTypeChanged(v);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PixivRestrict>(
              initialValue: restrict,
              decoration: const InputDecoration(
                labelText: '限制公开',
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
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('作品评论功能'),
              value: allowComment,
              onChanged: onAllowCommentChanged,
            ),
            if (showSexual)
              SwitchListTile(
                title: const Text('性相关内容'),
                value: sexual,
                onChanged: onSexualChanged,
              ),
            SwitchListTile(
              title: const Text('自动接受回复'),
              value: responseAutoAccept,
              onChanged: onResponseAutoAcceptChanged,
            ),
            SwitchListTile(
              title: const Text('原创声明'),
              value: original,
              onChanged: onOriginalChanged,
            ),
          ],
        ),
      ),
    );
  }
}
