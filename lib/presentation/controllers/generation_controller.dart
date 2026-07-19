import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/backend_mode.dart';
import '../../core/queue/generation_queue.dart';
import '../../domain/entities/advanced_generation.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/prompt_assistant.dart';
import '../../domain/repositories/generation_history_repository.dart';

class GenerationController extends ChangeNotifier {
  GenerationController({
    required GenerationQueue queue,
    required GenerationHistoryRepository historyRepository,
    required BackendMode Function() backendModeProvider,
    Uuid uuid = const Uuid(),
  }) : _queue = queue,
       _historyRepository = historyRepository,
       _backendModeProvider = backendModeProvider,
       _uuid = uuid {
    _queueSubscription = _queue.states.listen((value) {
      queueState = value;
      notifyListeners();
    });
    _taskSubscription = _queue.tasks.listen((task) {
      latestTask = task;
      notifyListeners();
    });
  }

  final GenerationQueue _queue;
  final GenerationHistoryRepository _historyRepository;
  final BackendMode Function() _backendModeProvider;
  final Uuid _uuid;
  late final StreamSubscription<GenerationQueueState> _queueSubscription;
  late final StreamSubscription<GenerationTask> _taskSubscription;

  GenerationMode mode = GenerationMode.textToImage;
  String model = 'nai-diffusion-4-5-full';
  String prompt = '';
  String negativePrompt = 'lowres, bad anatomy, text, watermark';
  int width = 832;
  int height = 1216;
  int steps = 28;
  double scale = 5;
  double cfgRescale = 0;
  String sampler = 'k_euler_ancestral';
  String noiseSchedule = 'karras';
  int seed = 0;
  int sampleCount = 1;
  double strength = 0.7;
  double noise = 0;
  String? sourceImagePath;
  String? maskImagePath;
  bool stream = false;
  List<CharacterPrompt> characterPrompts = const [];
  List<VibeReference> vibeReferences = const [];
  List<CharacterReference> characterReferences = const [];
  double controlnetStrength = 1;
  bool normalizeReferenceStrength = false;
  GenerationTask? latestTask;
  GenerationQueueState queueState = const GenerationQueueState.idle();

  void updatePrompt(String value) => prompt = value;
  void updateNegativePrompt(String value) => negativePrompt = value;
  void updateModel(String value) => model = value;

  void applyAssistantResult(PromptAssistantResult result) {
    prompt = result.positive.trim();
    negativePrompt = result.negative.trim();
    characterPrompts = result.characters
        .take(6)
        .map(
          (character) => CharacterPrompt(
            prompt: character.prompt,
            negativePrompt: character.negativePrompt,
          ),
        )
        .toList();
    notifyListeners();
  }

  void updateMode(GenerationMode value) {
    mode = value;
    if (value == GenerationMode.textToImage) {
      sourceImagePath = null;
      maskImagePath = null;
    } else if (value == GenerationMode.imageToImage) {
      maskImagePath = null;
    }
    notifyListeners();
  }

  void updateSize({required int width, required int height}) {
    this.width = width;
    this.height = height;
    notifyListeners();
  }

  void updateSteps(double value) {
    steps = value.round();
    notifyListeners();
  }

  void updateScale(double value) {
    scale = value;
    notifyListeners();
  }

  void updateSeed(String value) {
    seed = int.tryParse(value) ?? 0;
  }

  void randomizeSeed() {
    seed = Random.secure().nextInt(0x7fffffff);
    notifyListeners();
  }

  void updateStrength(double value) {
    strength = value;
    notifyListeners();
  }

  void updateNoise(double value) {
    noise = value;
    notifyListeners();
  }

  void setSourceImage(String? path) {
    sourceImagePath = path;
    notifyListeners();
  }

  void setMaskImage(String? path) {
    maskImagePath = path;
    notifyListeners();
  }

  void updateStream(bool value) {
    stream = value;
    notifyListeners();
  }

  void addCharacter() {
    if (characterPrompts.length >= 6) return;
    characterPrompts = [...characterPrompts, const CharacterPrompt(prompt: '')];
    notifyListeners();
  }

  void updateCharacter(int index, CharacterPrompt value) {
    characterPrompts = [...characterPrompts]..[index] = value;
    notifyListeners();
  }

  void removeCharacter(int index) {
    characterPrompts = [...characterPrompts]..removeAt(index);
    notifyListeners();
  }

  void addVibeReference(String imagePath) {
    vibeReferences = [...vibeReferences, VibeReference(imagePath: imagePath)];
    notifyListeners();
  }

  void updateVibeReference(int index, VibeReference value) {
    vibeReferences = [...vibeReferences]..[index] = value;
    notifyListeners();
  }

  void removeVibeReference(int index) {
    vibeReferences = [...vibeReferences]..removeAt(index);
    notifyListeners();
  }

  void addCharacterReference(String imagePath) {
    characterReferences = [
      ...characterReferences,
      CharacterReference(imagePath: imagePath),
    ];
    notifyListeners();
  }

  void updateCharacterReference(int index, CharacterReference value) {
    characterReferences = [...characterReferences]..[index] = value;
    notifyListeners();
  }

  void removeCharacterReference(int index) {
    characterReferences = [...characterReferences]..removeAt(index);
    notifyListeners();
  }

  void updateControlnetStrength(double value) {
    controlnetStrength = value;
    notifyListeners();
  }

  void updateNormalizeReferenceStrength(bool value) {
    normalizeReferenceStrength = value;
    notifyListeners();
  }

  String? validate() {
    if (prompt.trim().isEmpty) return '请输入正向提示词。';
    if (model.trim().isEmpty) return '请输入模型名称。';
    if (mode != GenerationMode.textToImage && sourceImagePath == null) {
      return '请先选择源图片。';
    }
    if (mode == GenerationMode.inpaint && maskImagePath == null) {
      return '请先绘制或选择蒙版。';
    }
    if (characterReferences.isNotEmpty && !model.contains('4-5')) {
      return '角色参考仅支持 NovelAI V4.5 模型。';
    }
    if (characterReferences.isNotEmpty &&
        _backendModeProvider() != BackendMode.native) {
      return '角色参考当前仅支持 NovelAI 原生后端。';
    }
    if (vibeReferences.any((reference) => !reference.hasSource)) {
      return 'Vibe 参考缺少图片或预编码数据。';
    }
    return null;
  }

  Future<GenerationTask> submit() async {
    final validation = validate();
    if (validation != null) throw StateError(validation);
    final now = DateTime.now().toUtc();
    final task = GenerationTask(
      id: _uuid.v4(),
      spec: GenerationSpec(
        mode: mode,
        backendMode: _backendModeProvider(),
        model: model.trim(),
        prompt: prompt.trim(),
        negativePrompt: negativePrompt.trim(),
        width: width,
        height: height,
        steps: steps,
        scale: scale,
        cfgRescale: cfgRescale,
        sampler: sampler,
        noiseSchedule: noiseSchedule,
        seed: seed == 0 ? Random.secure().nextInt(0x7fffffff) : seed,
        sampleCount: sampleCount,
        sourceImagePath: sourceImagePath,
        maskImagePath: maskImagePath,
        strength: strength,
        noise: noise,
        stream: stream,
        characterPrompts: characterPrompts,
        vibeReferences: vibeReferences,
        characterReferences: characterReferences,
        controlnetStrength: controlnetStrength,
        normalizeReferenceStrength: normalizeReferenceStrength,
      ),
      status: GenerationTaskStatus.queued,
      createdAt: now,
      updatedAt: now,
    );
    latestTask = await _queue.enqueue(task);
    notifyListeners();
    return latestTask!;
  }

  Future<void> cancelActive() async {
    final task = queueState.activeTask;
    if (task != null) await _queue.cancel(task.id);
  }

  Future<void> reuse(String taskId) async {
    final task = await _historyRepository.find(taskId);
    if (task == null) return;
    final spec = task.spec;
    mode = spec.mode;
    model = spec.model;
    prompt = spec.prompt;
    negativePrompt = spec.negativePrompt;
    width = spec.width;
    height = spec.height;
    steps = spec.steps;
    scale = spec.scale;
    cfgRescale = spec.cfgRescale;
    sampler = spec.sampler;
    noiseSchedule = spec.noiseSchedule;
    seed = spec.seed;
    sampleCount = spec.sampleCount;
    sourceImagePath = spec.sourceImagePath;
    maskImagePath = spec.maskImagePath;
    strength = spec.strength;
    noise = spec.noise;
    stream = spec.stream;
    characterPrompts = spec.characterPrompts;
    vibeReferences = spec.vibeReferences;
    characterReferences = spec.characterReferences;
    controlnetStrength = spec.controlnetStrength;
    normalizeReferenceStrength = spec.normalizeReferenceStrength;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_queueSubscription.cancel());
    unawaited(_taskSubscription.cancel());
    super.dispose();
  }
}
