# 发布检查清单

- [ ] 更新 `pubspec.yaml` 版本号与 `CHANGELOG.md`。
- [ ] `dart format --output=none --set-exit-if-changed lib test` 通过。
- [ ] `flutter analyze` 通过。
- [ ] `flutter test` 全量通过。
- [ ] `flutter build apk --release` 通过。
- [ ] 正式 Android 分发已配置私有 keystore。
- [ ] GitHub Actions iOS 生成 `NovelAICanvas.ipa` 与 SHA-256。
- [ ] 在目标 TrollStore 设备安装并完成启动、选图、保存与网络请求冒烟测试。
- [ ] 验证原生和网关连接、文生图、图生图、局部重绘与工具路由。
- [ ] 验证备份不含 Token/API Key，导出、导入及历史冲突处理正常。
- [ ] 验证 LLM 文本、Danbooru、Vision 警告和确认回填。
- [ ] 创建 `v*` Tag 并检查 GitHub Release 附件。
