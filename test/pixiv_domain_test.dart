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
        xRestrictDefault: PixivXRestrict.r18,
        cooldownMinutes: 15,
      );
      expect(s.xRestrictDefault, PixivXRestrict.r18);
      expect(s.r18Default, isTrue);
      expect(s.cooldownMinutes, 15);
      expect(s.defaultTags, ['NovelAI', 'AIイラスト']);
    });

    test('legacy r18Default alias maps onto xRestrictDefault', () {
      final s = PixivSettings.empty.copyWith(r18Default: true);
      expect(s.xRestrictDefault, PixivXRestrict.r18);
      expect(s.r18Default, isTrue);
    });

    test('attributes and ratings defaults are all false', () {
      expect(PixivSettings.empty.attributesDefault.bl, isFalse);
      expect(PixivSettings.empty.ratingsDefault.violent, isFalse);
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
        xRestrict: PixivXRestrict.general,
        aiType: PixivAiType.aiGenerated,
        restrict: PixivRestrict.public,
        allowComment: true,
        allowTagEdit: true,
        sexual: false,
        attributes: const PixivAttributes(),
        ratings: const PixivRatings(),
        responseAutoAccept: false,
        original: true,
        stripMetadata: true,
        createdAt: DateTime.now(),
      );

      expect(task.status, PixivUploadStatus.pending);
      expect(task.isR18, isFalse);
      final running = task.copyWith(status: PixivUploadStatus.uploading);
      expect(running.status, PixivUploadStatus.uploading);
    });

    test('isR18 is true for r18 and r18g', () {
      final r18 = PixivUploadTask(
        id: 'r18',
        imagePaths: const [],
        title: '',
        caption: '',
        tags: const [],
        xRestrict: PixivXRestrict.r18,
        aiType: PixivAiType.aiGenerated,
        restrict: PixivRestrict.public,
        allowComment: true,
        allowTagEdit: true,
        sexual: false,
        attributes: const PixivAttributes(),
        ratings: const PixivRatings(),
        responseAutoAccept: false,
        original: true,
        stripMetadata: true,
        createdAt: DateTime.now(),
      );
      expect(r18.isR18, isTrue);

      final r18g = r18.copyWith(xRestrict: PixivXRestrict.r18g);
      expect(r18g.isR18, isTrue);
    });
  });

  group('PixivAttributes', () {
    test('copyWith toggles individual flags', () {
      const a = PixivAttributes();
      final toggled = a.copyWith(bl: true, yuri: true);
      expect(toggled.bl, isTrue);
      expect(toggled.yuri, isTrue);
      expect(toggled.furry, isFalse);
    });
  });

  group('PixivRatings', () {
    test('copyWith toggles individual flags', () {
      const r = PixivRatings();
      final toggled = r.copyWith(violent: true, drug: true);
      expect(toggled.violent, isTrue);
      expect(toggled.drug, isTrue);
      expect(toggled.religion, isFalse);
    });
  });
}
