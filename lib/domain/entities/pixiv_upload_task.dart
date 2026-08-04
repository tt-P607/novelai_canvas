import 'package:equatable/equatable.dart';

/// Lifecycle of a single Pixiv publish job inside the upload queue.
enum PixivUploadStatus {
  pending,
  uploading,
  cooldown,
  completed,
  failed,
  canceled,
}

/// One Pixiv illustration submission. [imagePaths] are absolute local paths.
class PixivUploadTask extends Equatable {
  const PixivUploadTask({
    required this.id,
    required this.imagePaths,
    required this.title,
    required this.caption,
    required this.tags,
    required this.isR18,
    required this.allowTagEdit,
    required this.stripMetadata,
    required this.createdAt,
    this.status = PixivUploadStatus.pending,
    this.illustId,
    this.error,
    this.completedAt,
    this.cooldownUntil,
  });

  final String id;
  final List<String> imagePaths;
  final String title;
  final String caption;
  final List<String> tags;
  final bool isR18;
  final bool allowTagEdit;
  final bool stripMetadata;
  final PixivUploadStatus status;
  final String? illustId;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cooldownUntil;

  PixivUploadTask copyWith({
    List<String>? imagePaths,
    String? title,
    String? caption,
    List<String>? tags,
    bool? isR18,
    bool? allowTagEdit,
    bool? stripMetadata,
    PixivUploadStatus? status,
    String? illustId,
    String? error,
    DateTime? completedAt,
    DateTime? cooldownUntil,
    bool clearError = false,
    bool clearCooldown = false,
  }) {
    return PixivUploadTask(
      id: id,
      imagePaths: imagePaths ?? this.imagePaths,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      isR18: isR18 ?? this.isR18,
      allowTagEdit: allowTagEdit ?? this.allowTagEdit,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      status: status ?? this.status,
      illustId: illustId ?? this.illustId,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      cooldownUntil: clearCooldown
          ? null
          : (cooldownUntil ?? this.cooldownUntil),
    );
  }

  @override
  List<Object?> get props => [
    id,
    imagePaths,
    title,
    caption,
    tags,
    isR18,
    allowTagEdit,
    stripMetadata,
    status,
    illustId,
    error,
    createdAt,
    completedAt,
    cooldownUntil,
  ];
}
