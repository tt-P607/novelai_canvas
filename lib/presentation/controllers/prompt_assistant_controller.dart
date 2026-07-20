import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/local/prompt_chat_preferences.dart';
import '../../domain/entities/llm_assistant_settings.dart';
import '../../domain/entities/prompt_assistant.dart';
import '../../domain/repositories/prompt_assistant_repository.dart';
import 'llm_assistant_settings_controller.dart';

class PromptAssistantController extends ChangeNotifier {
  PromptAssistantController({
    required PromptAssistantRepository repository,
    required LlmAssistantSettingsController settingsController,
    required PromptChatPreferences preferences,
  }) : _repository = repository,
       _settingsController = settingsController,
       _preferences = preferences {
    _loadSessions();
  }

  final PromptAssistantRepository _repository;
  final LlmAssistantSettingsController _settingsController;
  final PromptChatPreferences _preferences;

  CancelToken? _cancelToken;

  List<PromptChatSession> sessions = const [];
  String? activeSessionId;
  String? pendingImagePath;
  bool isRunning = false;
  String? operationStatus;
  String? errorMessage;
  PromptChatMessage? failedMessage;
  PromptAssistantResult? latestPromptResult;

  LlmAssistantSettings get settings => _settingsController.settings;

  PromptChatSession get activeSession => sessions.firstWhere(
    (session) => session.id == activeSessionId,
    orElse: _emptySession,
  );

  List<PromptChatMessage> get messages => activeSession.messages;

  void _loadSessions() {
    sessions = _preferences.loadSessions();
    final storedId = _preferences.activeSessionId;
    activeSessionId = sessions.any((session) => session.id == storedId)
        ? storedId
        : sessions.where((session) => !session.archived).firstOrNull?.id;
    if (activeSessionId == null) _createSession(notify: false);
  }

  void newSession() => _createSession(notify: true);

  void _createSession({required bool notify}) {
    final now = DateTime.now();
    final session = PromptChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: '新对话',
      updatedAt: now,
    );
    sessions = [session, ...sessions];
    activeSessionId = session.id;
    latestPromptResult = null;
    pendingImagePath = null;
    _persist();
    if (notify) notifyListeners();
  }

  void selectSession(String id) {
    if (!sessions.any((session) => session.id == id)) return;
    activeSessionId = id;
    latestPromptResult = null;
    pendingImagePath = null;
    _preferences.setActiveSessionId(id);
    notifyListeners();
  }

  void setPendingImage(String? path) {
    pendingImagePath = path;
    notifyListeners();
  }

  Future<void> archiveActiveSession() async {
    final id = activeSessionId;
    if (id == null) return;
    sessions = sessions
        .map(
          (session) => session.id == id
              ? session.copyWith(archived: true, updatedAt: DateTime.now())
              : session,
        )
        .toList();
    final next = sessions.where((session) => !session.archived).firstOrNull;
    if (next == null) {
      _createSession(notify: true);
      return;
    }
    activeSessionId = next.id;
    await _persist();
    notifyListeners();
  }

  Future<void> unarchiveSession(String id) async {
    sessions = sessions
        .map(
          (session) => session.id == id
              ? session.copyWith(archived: false, updatedAt: DateTime.now())
              : session,
        )
        .toList();
    await _persist();
    notifyListeners();
  }

  void cancel() {
    final token = _cancelToken;
    if (token == null || token.isCancelled) return;
    token.cancel('用户已中止请求');
  }

  Future<void> send({
    required String text,
    required String currentPositive,
    required String currentNegative,
  }) async {
    final content = text.trim();
    final imagePath = pendingImagePath;
    if (content.isEmpty && imagePath == null) {
      errorMessage = '请输入消息或添加图片。';
      notifyListeners();
      return;
    }
    if (isRunning) return;
    isRunning = true;
    errorMessage = null;
    failedMessage = null;
    operationStatus = '正在准备请求…';
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    latestPromptResult = null;
    final now = DateTime.now();
    final userMessage = PromptChatMessage(
      role: PromptChatRole.user,
      content: content,
      imagePath: imagePath,
      createdAt: now,
    );
    pendingImagePath = null;
    _appendMessage(userMessage);
    notifyListeners();
    try {
      final reply = await _repository.chat(
        messages: messages,
        currentPositive: currentPositive,
        currentNegative: currentNegative,
        settings: settings,
        cancelToken: cancelToken,
        onStatus: (status) {
          if (!identical(_cancelToken, cancelToken)) return;
          operationStatus = status;
          notifyListeners();
        },
        onNotice: (notice) {
          if (!identical(_cancelToken, cancelToken)) return;
          _appendMessage(
            PromptChatMessage(
              role: PromptChatRole.notice,
              content: notice,
              createdAt: DateTime.now(),
            ),
          );
          notifyListeners();
        },
      );
      latestPromptResult = reply.promptResult;
      _appendMessage(
        PromptChatMessage(
          role: PromptChatRole.assistant,
          content: reply.message,
          createdAt: DateTime.now(),
          promptResult: reply.promptResult,
        ),
      );
      if (activeSession.messages
              .where((item) => item.role == PromptChatRole.user)
              .length ==
          1) {
        await _generateSessionTitle(cancelToken);
      }
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) {
        errorMessage = error.toString().replaceFirst(
          RegExp(r'^\w+Exception: '),
          '',
        );
        failedMessage = userMessage;
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst(
        RegExp(r'^\w+Exception: '),
        '',
      );
      failedMessage = userMessage;
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
      operationStatus = null;
      isRunning = false;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _generateSessionTitle(CancelToken cancelToken) async {
    final id = activeSessionId;
    if (id == null) return;
    final firstUserMessage = activeSession.messages.firstWhere(
      (message) => message.role == PromptChatRole.user,
      orElse: () =>
          const PromptChatMessage(role: PromptChatRole.user, content: ''),
    );
    if (firstUserMessage.content.trim().isEmpty) return;
    try {
      final titleReply = await _repository.chat(
        messages: [
          PromptChatMessage(
            role: PromptChatRole.user,
            content:
                '请根据下面的问题为当前对话生成一个简短标题，只输出标题，不超过16个汉字：${firstUserMessage.content}',
          ),
        ],
        currentPositive: '',
        currentNegative: '',
        settings: settings.copyWith(danbooruToolsEnabled: false),
        cancelToken: cancelToken,
      );
      final title = titleReply.message
          .replaceAll(RegExp(r'[“”"\n]'), '')
          .trim();
      if (title.isEmpty) return;
      sessions = sessions
          .map(
            (session) => session.id == id
                ? session.copyWith(
                    title: title.length > 20 ? title.substring(0, 20) : title,
                  )
                : session,
          )
          .toList();
    } catch (_) {
      // 标题生成失败不影响主对话。
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> retryLastFailure({
    required String currentPositive,
    required String currentNegative,
  }) async {
    final message = failedMessage;
    if (message == null) return;
    errorMessage = null;
    failedMessage = null;
    await retryMessage(
      message: message,
      currentPositive: currentPositive,
      currentNegative: currentNegative,
    );
  }

  Future<void> retryMessage({
    required PromptChatMessage message,
    required String currentPositive,
    required String currentNegative,
  }) async {
    if (message.role != PromptChatRole.user || isRunning) return;
    pendingImagePath = message.imagePath;
    await send(
      text: message.content,
      currentPositive: currentPositive,
      currentNegative: currentNegative,
    );
  }

  void _appendMessage(PromptChatMessage message) {
    final id = activeSessionId;
    if (id == null) return;
    sessions = sessions.map((session) {
      if (session.id != id) return session;
      final title = session.messages.isEmpty
          ? _titleFor(message.content, message.imagePath)
          : session.title;
      return session.copyWith(
        title: title,
        updatedAt: DateTime.now(),
        messages: [...session.messages, message],
      );
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _titleFor(String content, String? imagePath) {
    final value = content.trim();
    if (value.isEmpty) return imagePath == null ? '新对话' : '图片分析';
    return value.length > 24 ? '${value.substring(0, 24)}…' : value;
  }

  Future<void> _persist() async {
    await _preferences.saveSessions(sessions);
    final id = activeSessionId;
    if (id != null) await _preferences.setActiveSessionId(id);
  }

  PromptChatSession _emptySession() =>
      PromptChatSession(id: '', title: '新对话', updatedAt: DateTime.now());
}
