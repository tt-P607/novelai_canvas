# 构建与发布

## Android

本地执行 `flutter build apk --release`。若 `android/key.properties` 存在则使用正式 keystore，否则使用 debug key 生成侧载测试包。

GitHub Actions 正式签名 Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

## iOS TrollStore

使用 `flutter build ios --release --no-codesign` 生成 Runner.app，再打包为 Payload 结构，固定产物名 `NovelAICanvas.ipa`。该包无 Apple Developer 签名，只用于兼容的 TrollStore 环境。

## 自动化

项目沿用 Elysia Navi 的第三方 Codemagic 构建方式。`codemagic.yaml` 使用 `mac_mini_m2`，支持在 Codemagic 控制台手动运行，并可由 `v*` Tag 触发。构建产物直接从 Codemagic Artifacts 下载。

## 发布命令

```shell
git tag v1.0.0
git push origin v1.0.0
```

发布前必须完成格式化、静态分析、全量测试、Android Release 构建和 Codemagic iOS 构建验证。
