# 已知问题

- Windows 无法本地编译 iOS；必须使用 macOS、GitHub Actions 或 Codemagic。
- TrollStore IPA 未签名，不适用于 App Store、TestFlight 或普通系统安装。
- 未配置 Android keystore 时生成的 Release APK 使用 debug key，只适合侧载验证。
- JSON 备份不嵌入生成图片。跨设备恢复历史参数后，旧图片路径可能不可用。
- Vision 能否工作取决于用户配置的模型是否支持 OpenAI `image_url` 多模态输入。
- NovelAI 原生与自建网关能力不完全等价；角色参考等高级能力可能按后端降级。
- Danbooru 内置公共端点可能受网络、限流或服务可用性影响，可在助手设置中填写自定义地址。
