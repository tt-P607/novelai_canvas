import 'package:flutter/material.dart';

import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import 'glass/liquid_glass.dart';

/// Official presets that stay available regardless of the custom size fields.
const _officialSizes = <String, String>{
  '832x1216': '竖图 · 832 × 1216',
  '1024x1024': '方图 · 1024 × 1024',
  '1216x832': '横图 · 1216 × 832',
  '1024x1536': '大竖图 · 1024 × 1536 · 消耗 Anlas',
  '1536x1024': '大横图 · 1536 × 1024 · 消耗 Anlas',
};

class GenerationParameterCard extends StatelessWidget {
  const GenerationParameterCard({
    super.key,
    required this.controller,
    required this.modelController,
    required this.seedController,
    required this.widthController,
    required this.heightController,
    required this.onApplyCustomSize,
  });

  final GenerationController controller;
  final TextEditingController modelController;
  final TextEditingController seedController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final VoidCallback onApplyCustomSize;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('生成参数', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: modelController,
          onChanged: controller.updateModel,
          decoration: const InputDecoration(
            labelText: '模型',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _sizePresetField(),
        const SizedBox(height: 10),
        _customSizeRow(),
        const SizedBox(height: 4),
        Text(
          '范围 64–1600，保存时自动对齐到最接近的 64 倍数。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text('步数 ${controller.steps}'),
        Slider(
          value: controller.steps.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          onChanged: controller.updateSteps,
        ),
        Text('提示词相关性 ${controller.scale.toStringAsFixed(1)}'),
        Slider(
          value: controller.scale,
          min: 1,
          max: 10,
          divisions: 18,
          onChanged: controller.updateScale,
        ),
        _seedRow(),
        if (controller.mode != GenerationMode.textToImage) ..._strengthFields(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.stream_rounded),
          title: const Text('流式生成'),
          value: controller.stream,
          onChanged: controller.updateStream,
        ),
        if (controller.mode == GenerationMode.inpaint)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('边缘融合'),
            subtitle: const Text('默认开启，将原图叠加到结果边缘以减少局部重绘割裂'),
            value: controller.addOriginalImage,
            onChanged: controller.updateAddOriginalImage,
          ),
      ],
    ),
  );

  Widget _sizePresetField() {
    final current = '${controller.width}x${controller.height}';
    return DropdownButtonFormField<String>(
      initialValue: _officialSizes.containsKey(current) ? current : 'custom',
      decoration: const InputDecoration(labelText: '官方画幅预设'),
      items: [
        ..._officialSizes.entries.map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ),
        const DropdownMenuItem(value: 'custom', child: Text('自定义画幅')),
      ],
      onChanged: (value) {
        if (value == null || value == 'custom') return;
        final parts = value.split('x');
        controller.updateSize(
          width: int.parse(parts[0]),
          height: int.parse(parts[1]),
        );
      },
    );
  }

  Widget _customSizeRow() => Row(
    children: [
      Expanded(
        child: TextField(
          controller: widthController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '自定义宽度'),
          onSubmitted: (_) => onApplyCustomSize(),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('×'),
      ),
      Expanded(
        child: TextField(
          controller: heightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '自定义高度'),
          onSubmitted: (_) => onApplyCustomSize(),
        ),
      ),
      IconButton.filledTonal(
        tooltip: '应用自定义画幅',
        onPressed: onApplyCustomSize,
        icon: const Icon(Icons.check_rounded),
      ),
    ],
  );

  Widget _seedRow() => Row(
    children: [
      Expanded(
        child: TextField(
          controller: seedController,
          keyboardType: TextInputType.number,
          onChanged: controller.updateSeed,
          decoration: const InputDecoration(
            labelText: 'Seed（0 为随机）',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      IconButton(
        tooltip: '随机 Seed',
        onPressed: controller.randomizeSeed,
        icon: const Icon(Icons.casino_rounded),
      ),
    ],
  );

  List<Widget> _strengthFields() => [
    const SizedBox(height: 12),
    Text('重绘强度 ${controller.strength.toStringAsFixed(2)}'),
    Slider(
      value: controller.strength,
      min: 0,
      max: 1,
      divisions: 20,
      onChanged: controller.updateStrength,
    ),
    Text('噪声 ${controller.noise.toStringAsFixed(2)}'),
    Slider(
      value: controller.noise,
      min: 0,
      max: 1,
      divisions: 20,
      onChanged: controller.updateNoise,
    ),
  ];
}
