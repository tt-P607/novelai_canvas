# NovelAI Canvas · 绘境

基于 Flutter 的 NovelAI 移动创作客户端，一套代码支持 Android 与 iOS。项目同时支持 NovelAI 原生 API 和用户自建的 OpenAI 兼容网关。

## 功能

- 文生图、图生图、局部重绘与原生 SSE 中间预览。
- Vibe Transfer、V4.5 角色参考、多角色提示词与 5×5 坐标。
- 4× 放大、标签建议和六种导演工具。
- 持久化生成队列、SQLite 历史、收藏、搜索、参数复用与相册保存。
- OpenAI 兼容轻量提示词助手、Danbooru search/related 校准、可选 Vision 识图。
- 四套版本化可编辑 Prompt；确认后只回填草稿，不自动生图。
- 非敏感设置、Prompt 和历史参数的版本化备份与恢复；安全凭据始终排除。

## 环境

- Flutter 3.41.8 stable 或兼容的更新 stable。
- Dart 3.11.5 或满足 `pubspec.yaml` 的版本。
- Android 使用 JDK 17。
- iOS 构建需要 macOS、Xcode 和 CocoaPods。

## 本地运行

```shell
flutter pub get
flutter analyze
flutter test
flutter run
```

首次启动选择 NovelAI 原生模式，或填写网关 Base URL。NovelAI Token、网关 API Key 与 LLM API Key 均保存到系统 Keychain / Keystore。

## Android Release

未配置签名时，项目会使用 debug key 生成便于侧载验证的 release APK：

```shell
flutter build apk --release
```

正式分发时，将 `android/key.properties.example` 复制为不提交 Git 的 `android/key.properties`，填写 keystore 信息，并把 keystore 放到 `android/app/`。

## iOS TrollStore IPA

macOS 上执行：

```shell
flutter build ios --release --no-codesign
mkdir -p Payload
cp -R build/ios/iphoneos/Runner.app Payload/
ditto -c -k --sequesterRsrc --keepParent Payload NovelAICanvas.ipa
```

生成的 `NovelAICanvas.ipa` 未签名，供 TrollStore 安装。项目提供 GitHub Actions 与 Codemagic 自动构建配置。

## 云构建

项目沿用 Elysia Navi 使用的第三方 Codemagic：根目录的 `codemagic.yaml` 使用 macOS M2 Runner，执行无签名 iOS Release 构建并打包 `NovelAICanvas.ipa`。

在 Codemagic 中连接 `tt-P607/novelai_canvas` 仓库后，选择 `NovelAI Canvas iOS IPA (TrollStore)` 工作流手动构建；也可以推送 `v*` Tag 自动触发。构建完成后从 Codemagic Artifacts 下载 IPA 和 SHA-256 文件。

## 数据与隐私

备份文件只包含非敏感设置、LLM Prompt 和生成历史参数，不包含 NovelAI Token、网关 API Key 或 LLM API Key。图片文件本身不嵌入 JSON 备份，恢复后的历史仍会保留原本路径；跨设备恢复时需另行迁移图片。

## 文档

- `docs/architecture.md`
- `docs/api-matrix.md`
- `docs/llm-prompt-assistant.md`
- `docs/build-and-release.md`
- `docs/known-issues.md`
- `docs/release-checklist.md`

## 许可证

AGPL-3.0，详见 `LICENSE`。
