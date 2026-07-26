import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/error_message.dart';
import '../../core/network/backend_mode.dart';
import '../../core/queue/generation_queue.dart';
import '../../core/storage/image_size_reader.dart';
import '../../data/datasources/local/app_preferences.dart';
import '../../domain/entities/advanced_generation.dart';
import '../../domain/entities/anlas_estimate.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/prompt_assistant.dart';
import '../../domain/repositories/generation_history_repository.dart';

class GenerationController extends ChangeNotifier {
  GenerationController({
    required GenerationQueue queue,
    required GenerationHistoryRepository historyRepository,
    required BackendMode Function() backendModeProvider,
    AppPreferences? preferences,
    Future<int> Function()? subscriptionTierLoader,
    Uuid uuid = const Uuid(),
  }) : _queue = queue,
       _historyRepository = historyRepository,
       _backendModeProvider = backendModeProvider,
       _preferences = preferences,
       _subscriptionTierLoader = subscriptionTierLoader,
       _uuid = uuid,
       stream = preferences?.streamGenerationEnabled ?? false {
    _queue.taskInterval = Duration(
      milliseconds: preferences?.taskIntervalMs ?? 1000,
    );
    // Restore the cached tier so the badge and cost preview are correct on
    // cold start without waiting for the network round-trip.
    final cachedTier = preferences?.subscriptionTier;
    if (cachedTier != null) {
      subscriptionTier = cachedTier;
      isOpus = cachedTier >= 3;
    }
    _queueSubscription = _queue.states.listen((value) {
      queueState = value;
      notifyListeners();
    });
    _taskSubscription = _queue.tasks.listen((task) {
      latestTask = task;
      if (task.status == GenerationTaskStatus.completed &&
          task.imagePath != null) {
        latestImagePath = task.imagePath;
      }
      notifyListeners();
    });
  }

  final GenerationQueue _queue;
  final GenerationHistoryRepository _historyRepository;
  final BackendMode Function() _backendModeProvider;
  final AppPreferences? _preferences;
  final Future<int> Function()? _subscriptionTierLoader;
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

  /// Pixel dimensions of [sourceImagePath], once decoded.
  (int, int)? sourceImageSize;
  bool stream;
  bool addOriginalImage = true;
  List<CharacterPrompt> characterPrompts = const [];
  List<VibeReference> vibeReferences = const [];
  List<CharacterReference> characterReferences = const [];
  double controlnetStrength = 1;
  bool normalizeReferenceStrength = false;
  GenerationTask? latestTask;
  String? latestImagePath;
  GenerationQueueState queueState = const GenerationQueueState.idle();

  /// Opus is subscription tier 3; only it grants the free low-cost sample.
  bool isOpus = false;

  /// Null until the tier has been read at least once. The cost preview stays
  /// provisional in that state instead of claiming the account pays full price.
  int? subscriptionTier;
  bool subscriptionLoading = false;
  String? subscriptionError;

  bool get subscriptionKnown => subscriptionTier != null;

  String? get subscriptionTierName => switch (subscriptionTier) {
    null => null,
    1 => 'Tablet',
    2 => 'Scroll',
    3 => 'Opus',
    _ => 'Paper',
  };

  AnlasEstimate get anlasEstimate => estimateAnlas(
    width: width,
    height: height,
    steps: steps,
    sampleCount: sampleCount,
    isOpus: isOpus,
    strength: strength,
    hasSourceImage: sourceImagePath != null,
    hasMask: maskImagePath != null,
    characterReferenceCount: characterReferences
        .where((reference) => reference.enabled)
        .length,
    vibeReferenceCount: vibeReferences
        .where((reference) => reference.enabled)
        .length,
  );

  /// Opus grants one free sample below the low-cost threshold, so the estimate
  /// is meaningless until the tier is known.
  ///
  /// The controller outlives the creation page, and the token may still be
  /// missing on first open, so this stays retryable and surfaces failures
  /// instead of silently pinning the account to the non-Opus branch.
  /// Cached tiers older than this are re-validated in the background.
  static const subscriptionTtl = Duration(hours: 6);

  Future<void> refreshSubscription({bool force = false}) async {
    final loader = _subscriptionTierLoader;
    if (loader == null) return;
    if (subscriptionLoading) return;
    if (subscriptionKnown && !force && !_subscriptionStale) return;
    if (_backendModeProvider() != BackendMode.native) return;

    subscriptionLoading = true;
    subscriptionError = null;
    notifyListeners();
    try {
      final tier = await loader();
      subscriptionTier = tier;
      isOpus = tier >= 3;
      await _preferences?.setSubscriptionTier(tier, DateTime.now());
    } catch (error) {
      // A stale cached tier keeps working; only surface the failure when
      // there is nothing to show at all.
      if (!subscriptionKnown) {
        subscriptionError = friendlyErrorMessage(error);
      }
    } finally {
      subscriptionLoading = false;
      notifyListeners();
    }
  }

  bool get _subscriptionStale {
    final checkedAt = _preferences?.subscriptionCheckedAt;
    if (checkedAt == null) return true;
    return DateTime.now().difference(checkedAt) > subscriptionTtl;
  }

  void updatePrompt(String value) => prompt = value;
  void updateNegativePrompt(String value) => negativePrompt = value;
  void updateModel(String value) => model = value;

  void updateSampler(String value) {
    sampler = value;
    notifyListeners();
  }

  void updateNoiseSchedule(String value) {
    noiseSchedule = value;
    notifyListeners();
  }

  void updateCfgRescale(double value) {
    cfgRescale = value;
    notifyListeners();
  }

  void updateSampleCount(int value) {
    sampleCount = value.clamp(1, 4);
    notifyListeners();
  }

  void applyAssistantResult(PromptAssistantResult result) {
    prompt = result.positive.trim();
    negativePrompt = result.negative.trim();
    characterPrompts = result.characters
        .take(6)
        .map(
          (character) => CharacterPrompt(
            prompt: character.prompt,
            negativePrompt: character.negativePrompt,
            position: CharacterPosition(x: character.x, y: character.y),
            enabled: character.enabled,
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
    } else if (value == GenerationMode.inpaint) {
      final latest = latestImagePath;
      if (latest != null && latest.isNotEmpty) {
        setSourceImage(latest);
      }
      maskImagePath = null;
    }
    notifyListeners();
  }

  void updateSize({required int width, required int height}) {
    this.width = width.clamp(64, 1600);
    this.height = height.clamp(64, 1600);
    notifyListeners();
  }

  void updateCustomSize({required String width, required String height}) {
    final parsedWidth = int.tryParse(width);
    final parsedHeight = int.tryParse(height);
    if (parsedWidth == null || parsedHeight == null) return;
    updateSize(width: _align64(parsedWidth), height: _align64(parsedHeight));
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

  /// Adopts the source image and seeds the canvas with its real pixel size.
  ///
  /// The user may still pick any output size afterwards; keeping the source
  /// dimensions around lets the UI flag a mismatch instead of silently
  /// rescaling.
  void setSourceImage(String? path) {
    sourceImagePath = path;
    maskImagePath = null;
    sourceImageSize = null;
    notifyListeners();
    if (path == null || path.isEmpty) return;
    unawaited(_adoptSourceImageSize(path));
  }

  Future<void> _adoptSourceImageSize(String path) async {
    final size = await readImageSize(path);
    if (size == null || sourceImagePath != path) return;
    sourceImageSize = size;
    width = size.$1;
    height = size.$2;
    notifyListeners();
  }

  void setMaskImage(String? path) {
    maskImagePath = path;
    notifyListeners();
  }

  void updateStream(bool value) {
    stream = value;
    _preferences?.setStreamGenerationEnabled(value);
    notifyListeners();
  }

  void updateAddOriginalImage(bool value) {
    addOriginalImage = value;
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

  /// How many tasks one tap enqueues; the queue still executes them serially.
  int batchCount = 1;

  void updateBatchCount(int value) {
    batchCount = value.clamp(1, 15);
    notifyListeners();
  }

  /// Pause between consecutive tasks in seconds, persisted across restarts.
  double get taskIntervalSeconds => _queue.taskInterval.inMilliseconds / 1000;

  void updateTaskInterval(double seconds) {
    final millis = (seconds * 1000).round().clamp(
      GenerationQueue.minTaskInterval.inMilliseconds,
      60000,
    );
    _queue.taskInterval = Duration(milliseconds: millis);
    _preferences?.setTaskIntervalMs(millis);
    notifyListeners();
  }

  Future<GenerationTask> submit() async {
    final validation = validate();
    if (validation != null) throw StateError(validation);
    GenerationTask? last;
    // Serial batch: each task snapshots identical settings but rolls its own
    // seed (unless the user pinned one), matching NAI-WorldPainter's queue.
    for (var index = 0; index < batchCount; index++) {
      last = await _queue.enqueue(_buildTask());
    }
    latestTask = last;
    notifyListeners();
    return latestTask!;
  }

  GenerationTask _buildTask() {
    final backendMode = _backendModeProvider();
    final now = DateTime.now().toUtc();
    return GenerationTask(
      id: _uuid.v4(),
      spec: GenerationSpec(
        mode: mode,
        backendMode: backendMode,
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
        addOriginalImage: mode == GenerationMode.inpaint && addOriginalImage,
        stream: stream && backendMode == BackendMode.native,
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
    addOriginalImage = spec.mode == GenerationMode.inpaint
        ? spec.addOriginalImage
        : true;
    stream = spec.stream && spec.backendMode == BackendMode.native;
    characterPrompts = spec.characterPrompts;
    vibeReferences = spec.vibeReferences;
    characterReferences = spec.characterReferences;
    controlnetStrength = spec.controlnetStrength;
    normalizeReferenceStrength = spec.normalizeReferenceStrength;
    notifyListeners();
  }

  int _align64(int value) =>
      ((value.clamp(64, 1600) + 32) ~/ 64 * 64).clamp(64, 1600);

  @override
  void dispose() {
    unawaited(_queueSubscription.cancel());
    unawaited(_taskSubscription.cancel());
    super.dispose();
  }
}
