import '../entities/pixiv_settings.dart';
import '../entities/pixiv_upload_task.dart';

/// Submits illustrations to Pixiv and queries tag suggestions.
abstract interface class PixivUploadRepository {
  /// Uploads a single task. Returns the new illust id on success.
  Future<String> upload({
    required PixivSettings settings,
    required PixivUploadTask task,
  });

  /// Asks Pixiv for recommended tags based on the first image.
  Future<List<String>> suggestTags({
    required PixivSettings settings,
    required String imagePath,
  });
}
