import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/error_message.dart';
import '../../core/network/backend_connection_service.dart';
import '../../core/network/backend_mode.dart';
import '../../core/queue/generation_queue.dart';
import '../../core/storage/image_size_reader.dart';
import '../../data/datasources/local/app_preferences.dart';
import '../../domain/entities/advanced_generation.dart';
import '../../domain/entities/anlas_estimate.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/entities/prompt_assistant.dart';
import '../../domain/repositories/generation_history_repository.dart';

class GenerationController extends ChangeNotifier {
  GenerationController({
    required GenerationQueue queue,
    required GenerationHistoryRepository historyRepository,
    required BackendMode Function() backendModeProvider,
    BackendConnectionService? backendConnectionService,
    AppPreferences? preferences,
    Future<int> Function()? subscriptionTierLoader,
    Listenable? settingsListenable,
    Uuid uuid = const Uuid(),
  }) : _queue = queue,
       _historyRepository = historyRepository,
       _backendModeProvider = backendModeProvider,
       _backendConnectionService = backendConnectionService,
       _preferences = preferences,
       _subscriptionTierLoader = subscriptionTierLoader,
       _settingsListenable = settingsListenable,
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
    // Restore the last-used generation parameters so a cold start (the OS
    // reclaiming the app from the background) does not reset the user's
    // carefully tuned settings back to defaults.
    _restoreParams();
    _queueSubscription = _queue.states.listen((value) {
      queueState = value;
      notifyListeners();
    });
    _taskSubscription = _queue.tasks.listen((task) {
      latestTask = task;
      if (task.status == GenerationTaskStatus.completed &&
          task.imagePath != null) {
        // Check auto-follow BEFORE updating latestImagePath, so we can tell
        // whether the user was viewing the previous latest result.
        final wasFollowingLatest =
            selectedRecentImage == null ||
            selectedRecentImage == latestImagePath;
        latestImagePath = task.imagePath;
        // Prepend to the in-memory recent strip without duplicates. No cap —
        // the user can scroll back through the full session, and a ZIP export
        // covers the whole set.
        if (!recentImages.contains(task.imagePath)) {
          recentImages.insert(0, task.imagePath!);
        }
        if (wasFollowingLatest) {
          // Keep the user on the latest result. Pinning selectedRecentImage
          // here is safe because wasFollowingLatest was checked against the
          // previous latestImagePath — the user was (or would be) on the slot
          // that just completed.
          selectedRecentImage = task.imagePath;
        } else {
          // The user is browsing an older image — mark the new one unread.
          unviewedImages.add(task.imagePath!);
        }
      }
      notifyListeners();
    });
    // React to backend switches from the settings page without coupling the
    // settings controller to this one: refresh models and subscription state.
    _settingsListenable?.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    refreshModels(force: true);
    refreshSubscription(force: true);
  }

  final GenerationQueue _queue;
  final GenerationHistoryRepository _historyRepository;
  final BackendMode Function() _backendModeProvider;
  final BackendConnectionService? _backendConnectionService;
  final AppPreferences? _preferences;
  final Future<int> Function()? _subscriptionTierLoader;
  final Listenable? _settingsListenable;
  final Uuid _uuid;

  /// Models advertised by the active backend. Native mode keeps this empty so
  /// the UI falls back to the built-in catalogue; gateway mode fills it from
  /// `/v1/models` so the user picks a model the gateway actually supports.
  List<ModelInfo> availableModels = const [];
  bool modelsLoading = false;
  String? modelsError;
  late final StreamSubscription<GenerationQueueState> _queueSubscription;
  late final StreamSubscription<GenerationTask> _taskSubscription;

  /// Active backend. Gateway mode has no NovelAI subscription concept, so the
  /// tier badge, cost preview and subscription notice must be hidden there.
  BackendMode get backendMode => _backendModeProvider();

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

  /// Set when the source image was auto-resized to 64-alignment; the UI
  /// should show a one-shot notice and then clear it.
  String? resizeNotice;

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

  /// In-memory recent results shown as a compact thumbnail strip on the
  /// creation page. Cleared on app restart — for persistent history use the
  /// 作品 page. Each entry is the file path of a completed image.
  final List<String> recentImages = [];
  String? selectedRecentImage;

  /// Paths the user has not yet tapped to view. New completions are added
  /// here so the strip can highlight them; [selectRecentImage] clears the
  /// entry, marking it read.
  final Set<String> unviewedImages = {};

  /// Whether any task is currently queued or running. Since generation is
  /// strictly serial, only one placeholder tile is ever shown at a time.
  int get generatingSlots =>
      (queueState.pendingCount > 0 || queueState.isRunning) ? 1 : 0;

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
    uncachedVibeCount: vibeReferences
        .where(
          (reference) =>
              reference.enabled &&
              (reference.encodedData == null || reference.encodedData!.isEmpty),
        )
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

  /// Probes the gateway for `/v1/models` so the model picker only shows IDs
  /// the configured OpenAI-compatible backend actually recognises. Native
  /// mode keeps the built-in catalogue and clears any previously fetched list.
  Future<void> refreshModels({bool force = false}) async {
    final service = _backendConnectionService;
    if (service == null) return;
    if (modelsLoading) return;
    final mode = _backendModeProvider();
    if (mode != BackendMode.gateway) {
      if (availableModels.isNotEmpty) {
        availableModels = const [];
        notifyListeners();
      }
      return;
    }
    if (!force && availableModels.isNotEmpty) return;

    modelsLoading = true;
    modelsError = null;
    notifyListeners();
    try {
      final result = await service.probe(mode);
      if (!result.reachable) {
        modelsError = result.message ?? '无法连接到 OpenAI 兼容接口。';
        return;
      }
      availableModels = result.models;
      // If the saved model is not offered by this backend, switch to the first
      // available one so generation does not silently 404 on an unknown ID.
      if (result.models.isNotEmpty &&
          !result.models.any((m) => m.id == model)) {
        model = result.models.first.id;
        _saveParams();
      }
    } catch (error) {
      modelsError = friendlyErrorMessage(error);
    } finally {
      modelsLoading = false;
      notifyListeners();
    }
  }

  void updatePrompt(String value) {
    prompt = value;
    _saveParams();
  }

  void updateNegativePrompt(String value) {
    negativePrompt = value;
    _saveParams();
  }

  void updateModel(String value) {
    model = value;
    _saveParams();
    notifyListeners();
  }

  void updateSampler(String value) {
    sampler = value;
    _saveParams();
    notifyListeners();
  }

  void updateNoiseSchedule(String value) {
    noiseSchedule = value;
    _saveParams();
    notifyListeners();
  }

  void updateCfgRescale(double value) {
    cfgRescale = value;
    _saveParams();
    notifyListeners();
  }

  void updateSampleCount(int value) {
    sampleCount = value.clamp(1, 4);
    _saveParams();
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
    _saveParams();
    notifyListeners();
  }

  void updateSize({required int width, required int height}) {
    this.width = _align64(width);
    this.height = _align64(height);
    _saveParams();
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
    _saveParams();
    notifyListeners();
  }

  void updateScale(double value) {
    scale = value;
    _saveParams();
    notifyListeners();
  }

  void updateSeed(String value) {
    seed = int.tryParse(value) ?? 0;
    _saveParams();
  }

  void randomizeSeed() {
    seed = Random.secure().nextInt(0x7fffffff);
    _saveParams();
    notifyListeners();
  }

  void updateStrength(double value) {
    strength = value;
    _saveParams();
    notifyListeners();
  }

  void updateNoise(double value) {
    noise = value;
    _saveParams();
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
    final alignedW = _align64(size.$1);
    final alignedH = _align64(size.$2);
    if (alignedW != size.$1 || alignedH != size.$2) {
      final resized = await _autoResizeSource(path, alignedW, alignedH);
      if (resized != null) {
        sourceImagePath = resized;
        sourceImageSize = (alignedW, alignedH);
        resizeNotice =
            '源图 ${size.$1}×${size.$2} 非 64 对齐，已自动缩放为 $alignedW×$alignedH';
      }
    }
    width = alignedW;
    height = alignedH;
    notifyListeners();
  }

  /// Resizes the source image to 64-aligned dimensions and saves the result
  /// to the app's support directory. Returns the new path, or null on
  /// failure.
  Future<String?> _autoResizeSource(
    String originalPath,
    int targetW,
    int targetH,
  ) async {
    try {
      final sourceBytes = await File(originalPath).readAsBytes();
      final result = await compute(_resizeSourceImage, (
        sourceBytes,
        targetW,
        targetH,
      ));
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'resized_sources'));
      await dir.create(recursive: true);
      final newPath = p.join(
        dir.path,
        'src_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(newPath).writeAsBytes(result, flush: true);
      return newPath;
    } catch (_) {
      return null;
    }
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
    _saveParams();
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

  void addVibeReference(String imagePath, {String? encodedData}) {
    // Fresh image uploads start disabled — user must encode first.
    // Pre-encoded data (from vibe files) starts enabled.
    vibeReferences = [
      ...vibeReferences,
      VibeReference(
        imagePath: imagePath,
        encodedData: encodedData,
        enabled: encodedData != null && encodedData.isNotEmpty,
      ),
    ];
    notifyListeners();
  }

  void addVibeReferencesBatch(List<VibeReference> references) {
    vibeReferences = [...vibeReferences, ...references];
    notifyListeners();
  }

  Future<void> encodeVibeAt(
    int index,
    Future<String> Function(
      VibeReference reference,
      double informationExtracted,
    )
    encoder,
  ) async {
    final reference = vibeReferences[index];
    if (!reference.hasReencodeSource) return;
    final encoded = await encoder(reference, reference.informationExtracted);
    updateVibeReference(index, reference.withEncoding(encoded));
  }

  /// Updates the IE of a vibe and restores the cached encoding for that value
  /// when one exists, so switching between previously encoded IE values never
  /// costs Anlas again.
  void updateVibeInformationExtracted(int index, double value) {
    final reference = vibeReferences[index];
    updateVibeReference(index, reference.withInformationExtracted(value));
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
    _saveParams();
    notifyListeners();
  }

  void updateNormalizeReferenceStrength(bool value) {
    normalizeReferenceStrength = value;
    _saveParams();
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
    if (vibeReferences.any(
      (reference) =>
          reference.enabled &&
          !reference.hasEncoding &&
          !reference.hasReencodeSource,
    )) {
      return '当前信息提取值没有可用编码，且 Vibe 文件不含原始参考图。';
    }
    return null;
  }

  /// How many tasks one tap enqueues; the queue still executes them serially.
  int batchCount = 1;

  void updateBatchCount(int value) {
    batchCount = value.clamp(1, 15);
    _saveParams();
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
    log(
      '[GenController] _buildTask backendMode=${backendMode.name} '
      'mode=${mode.name} stream=$stream model="$model" '
      'availableModels=${availableModels.length}',
    );
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
        seed: seed == 0 ? Random.secure().nextInt(1000000000) : seed,
        sampleCount: sampleCount,
        sourceImagePath: sourceImagePath,
        maskImagePath: maskImagePath,
        strength: strength,
        noise: noise,
        addOriginalImage: mode == GenerationMode.inpaint && addOriginalImage,
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
  }

  Future<void> cancelActive() async {
    final task = queueState.activeTask;
    if (task != null) await _queue.cancel(task.id);
  }

  /// Cancels every queued (not-yet-running) task in one pass, leaving any
  /// in-flight request untouched.
  Future<void> cancelAllPending() => _queue.cancelPending();

  /// Selects a recent image to display in the result panel without leaving
  /// the creation page. Clears the unviewed badge so the strip stops
  /// highlighting it. Does NOT touch [latestImagePath] — that field tracks
  /// the most recent completion and is only set by the task stream, so the
  /// workbench can tell whether the user is still following the latest result.
  void selectRecentImage(String path) {
    selectedRecentImage = path;
    unviewedImages.remove(path);
    notifyListeners();
  }

  /// Removes a recent image from the in-memory strip.
  void removeRecentImage(String path) {
    recentImages.remove(path);
    if (selectedRecentImage == path) {
      selectedRecentImage = recentImages.isNotEmpty ? recentImages.first : null;
    }
    notifyListeners();
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
    stream = spec.stream;
    characterPrompts = spec.characterPrompts;
    vibeReferences = spec.vibeReferences;
    characterReferences = spec.characterReferences;
    controlnetStrength = spec.controlnetStrength;
    normalizeReferenceStrength = spec.normalizeReferenceStrength;
    notifyListeners();
  }

  /// Restores persisted generation parameters on cold start. Only scalar
  /// settings are restored — vibe/character references carry large payloads
  /// and are re-added by the user.
  void _restoreParams() {
    final prefs = _preferences;
    if (prefs == null) return;
    final params = prefs.generationParams;
    if (params.isEmpty) return;
    final m = params['mode']?.toString();
    if (m != null) {
      mode = GenerationMode.values.firstWhere(
        (v) => v.name == m,
        orElse: () => GenerationMode.textToImage,
      );
    }
    model = params['model']?.toString() ?? model;
    prompt = params['prompt']?.toString() ?? prompt;
    negativePrompt = params['negativePrompt']?.toString() ?? negativePrompt;
    width = (params['width'] as num?)?.toInt() ?? width;
    height = (params['height'] as num?)?.toInt() ?? height;
    steps = (params['steps'] as num?)?.toInt() ?? steps;
    scale = (params['scale'] as num?)?.toDouble() ?? scale;
    cfgRescale = (params['cfgRescale'] as num?)?.toDouble() ?? cfgRescale;
    sampler = params['sampler']?.toString() ?? sampler;
    noiseSchedule = params['noiseSchedule']?.toString() ?? noiseSchedule;
    seed = (params['seed'] as num?)?.toInt() ?? seed;
    sampleCount = (params['sampleCount'] as num?)?.toInt() ?? sampleCount;
    strength = (params['strength'] as num?)?.toDouble() ?? strength;
    noise = (params['noise'] as num?)?.toDouble() ?? noise;
    addOriginalImage = params['addOriginalImage'] != false;
    batchCount = (params['batchCount'] as num?)?.toInt() ?? batchCount;
    controlnetStrength =
        (params['controlnetStrength'] as num?)?.toDouble() ??
        controlnetStrength;
    normalizeReferenceStrength = params['normalizeReferenceStrength'] == true;
  }

  /// Persists the current scalar generation parameters. Called after each
  /// mutation so a background kill never loses the user's tuning.
  void _saveParams() {
    final prefs = _preferences;
    if (prefs == null) return;
    unawaited(
      prefs.setGenerationParams({
        'mode': mode.name,
        'model': model,
        'prompt': prompt,
        'negativePrompt': negativePrompt,
        'width': width,
        'height': height,
        'steps': steps,
        'scale': scale,
        'cfgRescale': cfgRescale,
        'sampler': sampler,
        'noiseSchedule': noiseSchedule,
        'seed': seed,
        'sampleCount': sampleCount,
        'strength': strength,
        'noise': noise,
        'addOriginalImage': addOriginalImage,
        'batchCount': batchCount,
        'controlnetStrength': controlnetStrength,
        'normalizeReferenceStrength': normalizeReferenceStrength,
      }),
    );
  }

  int _align64(int value) =>
      ((value.clamp(64, 1600) + 32) ~/ 64 * 64).clamp(64, 1600);

  @override
  void dispose() {
    _settingsListenable?.removeListener(_onSettingsChanged);
    unawaited(_queueSubscription.cancel());
    unawaited(_taskSubscription.cancel());
    super.dispose();
  }
}

Uint8List _resizeSourceImage((Uint8List, int, int) args) {
  final (sourceBytes, targetW, targetH) = args;
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) throw FormatException('无法解码图片。');
  final resized = img.copyResize(
    decoded,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodePng(resized));
}
