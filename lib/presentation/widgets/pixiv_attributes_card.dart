import 'package:flutter/material.dart';

import '../../domain/entities/pixiv_upload_task.dart';

/// Toggleable content attribute switches (BL / 百合 / 兽人 / 萝莉), mapped to
/// the `attributes[*]` form keys.
class PixivAttributesCard extends StatelessWidget {
  const PixivAttributesCard({
    super.key,
    required this.attributes,
    required this.onChanged,
  });

  final PixivAttributes attributes;
  final ValueChanged<PixivAttributes> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('内容属性', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('声明作品包含的题材属性', style: Theme.of(context).textTheme.bodySmall),
            SwitchListTile(
              title: const Text('BL ( Boys Love )'),
              value: attributes.bl,
              onChanged: (v) => onChanged(attributes.copyWith(bl: v)),
            ),
            SwitchListTile(
              title: const Text('百合'),
              value: attributes.yuri,
              onChanged: (v) => onChanged(attributes.copyWith(yuri: v)),
            ),
            SwitchListTile(
              title: const Text('兽人 / Furry'),
              value: attributes.furry,
              onChanged: (v) => onChanged(attributes.copyWith(furry: v)),
            ),
            SwitchListTile(
              title: const Text('萝莉'),
              value: attributes.lo,
              onChanged: (v) => onChanged(attributes.copyWith(lo: v)),
            ),
          ],
        ),
      ),
    );
  }
}
