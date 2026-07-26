import 'package:flutter/material.dart';

import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import 'canvas_size_field.dart';
import 'glass/liquid_glass.dart';

const _samplers = <String, String>{
  'k_euler': 'Euler',
  'k_euler_ancestral': 'Euler Ancestral',
  'k_dpm_2': 'DPM2',
  'k_dpm_2_ancestral': 'DPM2 Ancestral',
  'k_dpmpp_2m': 'DPM++ 2M',
  'k_dpmpp_2s_ancestral': 'DPM++ 2S Ancestral',
  'k_dpmpp_sde': 'DPM++ SDE',
  'ddim': 'DDIM',
};

const _noiseSchedules = <String, String>{
  'karras': 'Karras',
  'exponential': 'Exponential',
  'polyexponential': 'Polyexponential',
};

/// Generation settings, collapsed by default so the creation page stays short.
///
/// Mirrors the official layout: common controls up front and rarely touched
/// knobs behind a nested "高级设置" disclosure.
class GenerationParameterCard extends StatefulWidget {
  const GenerationParameterCard({
    super.key,
    required this.controller,
    required this.modelController,
    required this.seedController,
    required this.widthController,
    required this.heightController,
  });

  final GenerationController controller;
  final TextEditingController modelController;
  final TextEditingController seedController;
  final TextEditingController widthController;
  final TextEditingController heightController;

  @override
  State<GenerationParameterCard> createState() =>
      _GenerationParameterCardState();
}

class _GenerationParameterCardState extends State<GenerationParameterCard> {
  bool _expanded = false;
  bool _advancedExpanded = false;

  GenerationController get controller => widget.controller;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _body(),
        ),
      ],
    ),
  );

  Widget _header() => InkWell(
    onTap: () => setState(() => _expanded = !_expanded),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text('生成参数', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 10),
          Expanded(child: _summary()),
          AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.expand_more_rounded),
          ),
        ],
      ),
    ),
  );

  /// Keeps the most-changed values visible while collapsed.
  Widget _summary() {
    if (_expanded) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Text(
      '${controller.width}×${controller.height} · '
      '${controller.steps} 步 · '
      '${_samplers[controller.sampler] ?? controller.sampler}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
    );
  }

  Widget _body() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.modelController,
          onChanged: controller.updateModel,
          decoration: const InputDecoration(
            labelText: '模型',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        CanvasSizeField(
          width: controller.width,
          height: controller.height,
          widthController: widget.widthController,
          heightController: widget.heightController,
          onChanged: (width, height) =>
              controller.updateSize(width: width, height: height),
        ),
        if (controller.mode != GenerationMode.textToImage) _sourceSizeHint(),
        const SizedBox(height: 16),
        _slider(
          label: '步数',
          value: controller.steps.toDouble(),
          display: '${controller.steps}',
          min: 1,
          max: 50,
          divisions: 49,
          onChanged: controller.updateSteps,
        ),
        _slider(
          label: '提示词相关性',
          value: controller.scale,
          display: controller.scale.toStringAsFixed(1),
          min: 1,
          max: 10,
          divisions: 18,
          onChanged: controller.updateScale,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _seedField()),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                label: '采样器',
                value: controller.sampler,
                options: _samplers,
                onChanged: controller.updateSampler,
              ),
            ),
          ],
        ),
        if (controller.mode != GenerationMode.textToImage) ..._strengthFields(),
        const SizedBox(height: 6),
        _advancedSection(),
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

  Widget _advancedSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('高级设置', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _advancedExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
      AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        sizeCurve: Curves.easeOutCubic,
        crossFadeState: _advancedExpanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: const SizedBox(width: double.infinity),
        secondChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slider(
              label: '相关性缩放',
              value: controller.cfgRescale,
              display: controller.cfgRescale.toStringAsFixed(2),
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: controller.updateCfgRescale,
            ),
            const SizedBox(height: 4),
            _dropdown(
              label: '噪声调度',
              value: controller.noiseSchedule,
              options: _noiseSchedules,
              onChanged: controller.updateNoiseSchedule,
            ),
            const SizedBox(height: 12),
            Text('生成数量', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {controller.sampleCount},
              onSelectionChanged: (value) =>
                  controller.updateSampleCount(value.single),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ],
  );

  Widget _slider({
    required String label,
    required double value,
    required String display,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          Text(
            display,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: options.containsKey(value) ? value : options.keys.first,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: options.entries
        .map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        )
        .toList(),
    onChanged: (selected) {
      if (selected != null) onChanged(selected);
    },
  );

  Widget _seedField() => TextField(
    controller: widget.seedController,
    keyboardType: TextInputType.number,
    onChanged: controller.updateSeed,
    decoration: InputDecoration(
      labelText: 'Seed',
      hintText: '0 为随机',
      isDense: true,
      suffixIcon: IconButton(
        tooltip: '随机 Seed',
        onPressed: controller.randomizeSeed,
        icon: const Icon(Icons.casino_rounded, size: 20),
      ),
    ),
  );

  /// Surfaces the source resolution so a mismatch with the chosen output canvas
  /// is visible before generating, and offers a one-tap way back to it.
  Widget _sourceSizeHint() {
    final source = controller.sourceImageSize;
    if (source == null) return const SizedBox.shrink();
    final matches =
        source.$1 == controller.width && source.$2 == controller.height;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            matches ? Icons.straighten_rounded : Icons.crop_rounded,
            size: 18,
            color: matches ? colors.onSurfaceVariant : colors.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              matches
                  ? '源图 ${source.$1} × ${source.$2}，与输出画幅一致。'
                  : '源图 ${source.$1} × ${source.$2}，将被适配到输出画幅。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: matches ? colors.onSurfaceVariant : colors.tertiary,
              ),
            ),
          ),
          if (!matches)
            TextButton(
              onPressed: () =>
                  controller.updateSize(width: source.$1, height: source.$2),
              child: const Text('用源图尺寸'),
            ),
        ],
      ),
    );
  }

  List<Widget> _strengthFields() => [
    const SizedBox(height: 8),
    _slider(
      label: '重绘强度',
      value: controller.strength,
      display: controller.strength.toStringAsFixed(2),
      min: 0,
      max: 1,
      divisions: 20,
      onChanged: controller.updateStrength,
    ),
    _slider(
      label: '噪声',
      value: controller.noise,
      display: controller.noise.toStringAsFixed(2),
      min: 0,
      max: 1,
      divisions: 20,
      onChanged: controller.updateNoise,
    ),
  ];
}
