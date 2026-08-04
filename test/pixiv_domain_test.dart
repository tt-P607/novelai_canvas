import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/domain/entities/pixiv_settings.dart';
import 'package:novelai_canvas/domain/entities/pixiv_upload_task.dart';

void main() {
  group('PixivSettings', () {
    test(
      'hasCredentials returns true only when cookie and csrfToken are non-empty',
      () {
        expect(PixivSettings.empty.hasCredentials, isFalse);
        final valid = PixivSettings.empty.copyWith(
          cookie: 'test_cookie',
          csrfToken: 'test_csrf',
        );
        expect(valid.hasCredentials, isTrue);
      },
    );

    test('copyWith updates fields correctly', () {
      final s = PixivSettings.empty.copyWith(
        r18Default: true,
        cooldownMinutes: 15,
      );
      expect(s.r18Default, isTrue);
      expect(s.cooldownMinutes, 15);
      expect(s.defaultTags, ['NovelAI', 'AIイラスト']);
    });
  });

  group('PixivUploadTask', () {
    test('task status copyWith operates as expected', () {
      final task = PixivUploadTask(
        id: '123',
        imagePaths: ['/tmp/1.png'],
        title: 'Test',
        caption: 'Caption',
        tags: ['tag1'],
        isR18: false,
        allowTagEdit: true,
        stripMetadata: true,
        createdAt: DateTime.now(),
      );

      expect(task.status, PixivUploadStatus.pending);
      final running = task.copyWith(status: PixivUploadStatus.uploading);
      expect(running.status, PixivUploadStatus.uploading);
    });
  });
}
