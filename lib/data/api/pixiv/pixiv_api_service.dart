import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../domain/entities/pixiv_settings.dart';
import '../../../domain/entities/pixiv_upload_task.dart';

class PixivUploadException implements Exception {
  const PixivUploadException(this.message, {this.raw});
  final String message;
  final Object? raw;
  @override
  String toString() => 'PixivUploadException: $message';
}

class PixivCooldownException implements Exception {
  const PixivCooldownException(this.message);
  final String message;
  @override
  String toString() => 'PixivCooldownException: $message';
}

class PixivAuthException implements Exception {
  const PixivAuthException(this.message);
  final String message;
  @override
  String toString() => 'PixivAuthException: $message';
}

/// Calls Pixiv internal AJAX endpoints by impersonating a logged-in browser
/// session (Cookie + x-csrf-token). Ported from NAI-WorldPainter.
class PixivApiService {
  final _uuid = const Uuid();

  Dio _buildDio(PixivSettings s) {
    final adapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..idleTimeout = const Duration(minutes: 5)
          ..connectionTimeout = const Duration(seconds: 30)
          ..badCertificateCallback = (_, _, _) => true;
        final proxy = _parseProxy(s.proxy.trim());
        if (proxy != null) {
          client.findProxy = (_) => 'PROXY $proxy';
        }
        return client;
      },
    );

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
        validateStatus: (_) => true,
        headers: _baseHeaders(s),
      ),
    )..httpClientAdapter = adapter;

    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            debugPrint('[Pixiv] >>> ${o.method} ${o.uri}');
            h.next(o);
          },
          onResponse: (r, h) {
            debugPrint('[Pixiv] <<< ${r.statusCode} ${r.requestOptions.uri}');
            h.next(r);
          },
          onError: (e, h) {
            debugPrint('[Pixiv] !!! ${e.type} ${e.message}');
            h.next(e);
          },
        ),
      );
    }
    return dio;
  }

  String? _parseProxy(String raw) {
    try {
      final uri = Uri.parse(raw.contains('://') ? raw : 'http://$raw');
      if (uri.host.isEmpty) return null;
      final port = uri.hasPort ? uri.port : 80;
      return '${uri.host}:$port';
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _baseHeaders(PixivSettings s) {
    return {
      'accept': 'application/json',
      'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'origin': 'https://www.pixiv.net',
      'referer': 'https://www.pixiv.net/illustration/create',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Edg/122.0.0.0',
      'cookie': s.cookie,
      'x-csrf-token': s.csrfToken,
      'sentry-trace':
          '${_uuid.v4().replaceAll('-', '')}-${_uuid.v4().replaceAll('-', '').substring(0, 16)}-"0"',
    };
  }

  Future<List<String>> suggestTags({
    required PixivSettings settings,
    required String imagePath,
  }) async {
    if (!settings.hasCredentials) {
      throw const PixivAuthException('未配置 Pixiv Cookie / CSRF Token');
    }
    final dio = _buildDio(settings);
    final file = File(imagePath);
    if (!await file.exists()) {
      throw PixivUploadException('图片不存在: $imagePath');
    }
    final mime = p.extension(imagePath).toLowerCase() == '.png'
        ? 'image/png'
        : 'image/jpeg';

    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        await file.readAsBytes(),
        filename: p.basename(imagePath),
        contentType: DioMediaType.parse(mime),
      ),
    });

    final resp = await dio.post(
      'https://www.pixiv.net/rpc/suggest_tags_by_image.php',
      data: form,
    );

    if (resp.statusCode != 200) {
      throw PixivUploadException(
        '推荐 tag 失败: HTTP ${resp.statusCode}',
        raw: resp.data,
      );
    }
    final body = resp.data;
    if (body is! Map) {
      throw const PixivUploadException('推荐 tag 响应格式异常');
    }
    if (body['error'] == true) {
      throw PixivAuthException('Pixiv 返回错误: ${body['message'] ?? body}');
    }
    final tags = (body['body']?['tags'] as List?) ?? const [];
    return tags.map((e) => e.toString()).toList();
  }

  Future<String> uploadIllustration({
    required PixivSettings settings,
    required PixivUploadTask task,
  }) async {
    if (!settings.hasCredentials) {
      throw const PixivAuthException('未配置 Pixiv Cookie / CSRF Token');
    }
    if (task.imagePaths.isEmpty) {
      throw const PixivUploadException('未选择图片');
    }
    final dio = _buildDio(settings);

    final formMap = <String, dynamic>{
      'aiType': switch (task.aiType) {
        PixivAiType.human => 'notAiGenerated',
        PixivAiType.aiGenerated => 'aiGenerated',
      },
      'allowComment': task.allowComment ? 'true' : 'false',
      'allowTagEdit': task.allowTagEdit ? 'true' : 'false',
      'attributes[bl]': task.attributes.bl ? 'true' : 'false',
      'attributes[furry]': task.attributes.furry ? 'true' : 'false',
      'attributes[lo]': task.attributes.lo ? 'true' : 'false',
      'attributes[yuri]': task.attributes.yuri ? 'true' : 'false',
      'caption': task.caption,
      'captionTranslations[en]': '',
      'original': task.original ? 'true' : 'false',
      'ratings[antisocial]': task.ratings.antisocial ? 'true' : 'false',
      'ratings[drug]': task.ratings.drug ? 'true' : 'false',
      'ratings[religion]': task.ratings.religion ? 'true' : 'false',
      'ratings[thoughts]': task.ratings.thoughts ? 'true' : 'false',
      'ratings[violent]': task.ratings.violent ? 'true' : 'false',
      'responseAutoAccept': task.responseAutoAccept ? 'true' : 'false',
      'restrict': switch (task.restrict) {
        PixivRestrict.public => 'public',
        PixivRestrict.myFans => 'myFans',
        PixivRestrict.myFriends => 'myFriends',
      },
      'suggestedTags[]': const <String>['女の子'],
      'tags[]': task.tags,
      'title': task.title,
      'titleTranslations[en]': '',
      'xRestrict': switch (task.xRestrict) {
        PixivXRestrict.general => 'general',
        PixivXRestrict.r18 => 'r18',
        PixivXRestrict.r18g => 'r18g',
      },
    };
    // Pixiv forces sexual=false for all-ages works; only R-18/R-18G may opt in.
    if (task.xRestrict == PixivXRestrict.general) {
      formMap['sexual'] = 'false';
    } else {
      formMap['sexual'] = task.sexual ? 'true' : 'false';
    }

    for (int i = 0; i < task.imagePaths.length; i++) {
      final path = task.imagePaths[i];
      final file = File(path);
      if (!await file.exists()) {
        throw PixivUploadException('图片不存在: $path');
      }
      final mime = p.extension(path).toLowerCase() == '.png'
          ? 'image/png'
          : 'image/jpeg';
      formMap['files[]'] = formMap['files[]'] ?? <MultipartFile>[];
      (formMap['files[]'] as List).add(
        MultipartFile.fromBytes(
          await file.readAsBytes(),
          filename: p.basename(path),
          contentType: DioMediaType.parse(mime),
        ),
      );
      formMap['imageOrder[$i][fileKey]'] = '$i';
      formMap['imageOrder[$i][type]'] = 'newFile';
    }

    final form = FormData();
    formMap.forEach((k, v) {
      if (v is List) {
        for (final item in v) {
          if (item is MultipartFile) {
            form.files.add(MapEntry(k, item));
          } else {
            form.fields.add(MapEntry(k, item.toString()));
          }
        }
      } else if (v is MultipartFile) {
        form.files.add(MapEntry(k, v));
      } else {
        form.fields.add(MapEntry(k, v.toString()));
      }
    });

    final resp = await dio.post(
      'https://www.pixiv.net/ajax/work/create/illustration',
      data: form,
    );

    final data = resp.data;
    if (data is! Map) {
      throw PixivUploadException(
        '上传响应格式异常: HTTP ${resp.statusCode}',
        raw: data,
      );
    }

    if (data['error'] == true) {
      final errors = data['body']?['errors'];
      if (errors is Map && errors['gRecaptchaResponse'] != null) {
        throw const PixivCooldownException('投稿冷却（gRecaptcha），请稍后再试');
      }
      final msg =
          data['message']?.toString() ?? errors?.toString() ?? 'unknown error';
      if (msg.contains('csrf') ||
          msg.contains('CSRF') ||
          msg.contains('未登录') ||
          msg.contains('login')) {
        throw PixivAuthException(msg);
      }
      throw PixivUploadException('上传失败: $msg', raw: data);
    }

    final convertKey = data['body']?['convertKey']?.toString();
    if (convertKey == null || convertKey.isEmpty) {
      throw PixivUploadException('未获取到 convertKey', raw: data);
    }

    return _pollProgress(dio: dio, convertKey: convertKey);
  }

  Future<String> _pollProgress({
    required Dio dio,
    required String convertKey,
  }) async {
    final url =
        'https://www.pixiv.net/ajax/work/create/illustration/progress'
        '?convertKey=$convertKey&lang=zh';
    for (int i = 0; i < 120; i++) {
      final resp = await dio.get(url);
      final data = resp.data;
      if (data is Map && data['body'] is Map) {
        final status = data['body']['status']?.toString();
        if (status == 'COMPLETE') {
          final illustId = data['body']['illustId']?.toString();
          if (illustId == null || illustId.isEmpty) {
            throw const PixivUploadException('完成但未返回 illustId');
          }
          return illustId;
        }
        if (status == 'FAILED') {
          throw const PixivUploadException('Pixiv 处理失败');
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    throw const PixivUploadException('上传进度查询超时');
  }
}
