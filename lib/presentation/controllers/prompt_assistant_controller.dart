import 'package:flutter/foundation.dart';

import '../../domain/entities/llm_assistant_settings.dart';
import '../../domain/entities/prompt_assistant.dart';
import '../../domain/repositories/prompt_assistant_repository.dart';
import 'llm_assistant_settings_controller.dart';

class PromptAssistantController extends ChangeNotifier {
  PromptAssistantController({
    required PromptAssistantRepository repository,
    required LlmAssistantSettingsController settingsController,
  }) : _repository = repository,
       _settingsController = settingsController;

  final PromptAssistantRepository _repository;
  final LlmAssistantSettingsController _settingsController;

  String description = '';
  String? imagePath;
  bool isRunning = false;
  String status = '';
  String? errorMessage;
  ExtractedKeywords? keywords;
  DanbooruTagPool? tagPool;
  PromptAssistantResult? result;

  LlmAssistantSettings get settings => _settingsController.settings;

  void updateDescription(String value) => description = value;

  void setImagePath(String? value) {
    imagePath = value;
    notifyListeners();
  }

  void clearResult() {
    keywords = null;
    tagPool = null;
    result = null;
    errorMessage = null;
    status = '';
    notifyListeners();
  }

  Future<void> analyzeVision() async {
    final path = imagePath;
    if (path == null) {
      errorMessage = '请先选择一张图片。';
      notifyListeners();
      return;
    }
    await _run(() async {
      status = '正在调用多模态模型识图…';
      notifyListeners();
      description = await _repository.analyzeImage(
        imagePath: path,
        instruction: description,
        settings: settings,
      );
      status = '识图完成，请检查描述后再整理。';
    });
  }

  Future<void> generate({
    required String currentPositive,
    required String currentNegative,
  }) async {
    if (description.trim().isEmpty) {
      errorMessage = '请输入自然语言画面描述，或先使用 Vision 识图。';
      notifyListeners();
      return;
    }
    await _run(() async {
      status = '正在提取 Danbooru 检索关键词…';
      notifyListeners();
      keywords = await _repository.extractKeywords(
        description: description,
        settings: settings,
      );
      status = '正在查询 Danbooru search / related…';
      notifyListeners();
      tagPool = await _repository.searchTags(
        keywords: keywords!,
        settings: settings,
      );
      status = '正在基于真实候选池整理提示词…';
      notifyListeners();
      result = await _repository.compose(
        description: description,
        keywords: keywords!,
        tagPool: tagPool!,
        currentPositive: currentPositive,
        currentNegative: currentNegative,
        settings: settings,
      );
      status = '整理完成。确认后才会回填创作页，不会自动生成。';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (isRunning) return;
    isRunning = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      errorMessage = error.toString().replaceFirst(
        RegExp(r'^\w+Exception: '),
        '',
      );
      status = '';
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }
}
