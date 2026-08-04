import 'package:flutter/material.dart';

import '../../domain/entities/pixiv_upload_task.dart';

/// Toggleable safety rating switches (暴力 / 反社会 / 毒品 / 宗教 / 思想),
/// mapped to the `ratings[*]` form keys.
class PixivRatingsCard extends StatelessWidget {
  const PixivRatingsCard({
    super.key,
    required this.ratings,
    required this.onChanged,
  });

  final PixivRatings ratings;
  final ValueChanged<PixivRatings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安全评级', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('声明作品包含的敏感内容', style: Theme.of(context).textTheme.bodySmall),
            SwitchListTile(
              title: const Text('暴力表现'),
              value: ratings.violent,
              onChanged: (v) => onChanged(ratings.copyWith(violent: v)),
            ),
            SwitchListTile(
              title: const Text('反社会行为'),
              value: ratings.antisocial,
              onChanged: (v) => onChanged(ratings.copyWith(antisocial: v)),
            ),
            SwitchListTile(
              title: const Text('毒品'),
              value: ratings.drug,
              onChanged: (v) => onChanged(ratings.copyWith(drug: v)),
            ),
            SwitchListTile(
              title: const Text('宗教'),
              value: ratings.religion,
              onChanged: (v) => onChanged(ratings.copyWith(religion: v)),
            ),
            SwitchListTile(
              title: const Text('思想'),
              value: ratings.thoughts,
              onChanged: (v) => onChanged(ratings.copyWith(thoughts: v)),
            ),
          ],
        ),
      ),
    );
  }
}
