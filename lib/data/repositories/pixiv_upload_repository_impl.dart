import '../api/pixiv/pixiv_api_service.dart';
import '../../domain/entities/pixiv_settings.dart';
import '../../domain/entities/pixiv_upload_task.dart';
import '../../domain/repositories/pixiv_upload_repository.dart';

class PixivUploadRepositoryImpl implements PixivUploadRepository {
  PixivUploadRepositoryImpl(this._api);

  final PixivApiService _api;

  @override
  Future<String> upload({
    required PixivSettings settings,
    required PixivUploadTask task,
  }) {
    return _api.uploadIllustration(settings: settings, task: task);
  }

  @override
  Future<List<String>> suggestTags({
    required PixivSettings settings,
    required String imagePath,
  }) {
    return _api.suggestTags(settings: settings, imagePath: imagePath);
  }
}
