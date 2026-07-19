# 开发交接说明

## 1. 当前交付状态

当前提交是可运行、可安装的首个完整基础版本，不代表产品已经完成最终验收。用户已在 Android 实机确认“基础可用”，同时明确反馈仍存在较多体验和功能问题。后续维护者应优先收集具体复现步骤，按严重程度继续修复，不应把当前版本视为稳定正式版。

已完成的主能力：

- Flutter Android/iOS 双端工程，包名 `com.elysia.novelaicanvas`。
- NovelAI 原生 API 与 OpenAI 兼容网关双后端。
- 文生图、图生图、局部重绘、原生 SSE 中间预览。
- Vibe、多角色、5×5 坐标、V4.5 角色参考。
- 放大、标签建议、六种导演工具。
- 持久化生成队列、SQLite 历史、收藏、搜索、保存和参数复用。
- OpenAI 兼容提示词助手、Danbooru 校准、可选 Vision、四套可编辑 Prompt。
- 非敏感设置、Prompt 与历史参数的 JSON 备份/恢复。
- Android Release 构建与 Codemagic TrollStore IPA 云构建配置。

当前验证结果：

- `dart format --output=none --set-exit-if-changed lib test`：通过。
- `flutter analyze`：通过，无问题。
- `flutter test`：28 项全部通过。
- Android Release APK：构建成功，约 55.6 MB。
- APK SHA-256：`12bdb5239764bb6cdbc34e8d6fd7145756cd42d1ac58e56e685006cd3642ddb1`。
- iOS IPA：Codemagic 构建配置已完成，但尚未在 macOS Runner 实际验证。

## 2. 重要目录与入口

- 应用入口：`lib/main.dart`
- 依赖注入：`lib/core/di/injection.dart`
- 双后端请求层：`lib/data/api/native`、`lib/data/api/gateway`
- 统一生成仓库：`lib/data/repositories/generation_repository_impl.dart`
- 持久化队列：`lib/core/queue/generation_queue.dart`
- SQLite：`lib/data/datasources/local/generation_database.dart`
- 备份服务：`lib/core/backup/app_backup_service.dart`
- 创作页：`lib/presentation/pages/creation_page.dart`
- 作品页：`lib/presentation/pages/history_page.dart`
- 工具页：`lib/presentation/pages/image_tools_page.dart`
- 设置页：`lib/presentation/pages/settings_page.dart`
- 提示词助手：`lib/data/repositories/prompt_assistant_repository_impl.dart`
- API 文档：工作区上级 `NOVELAI_API_DOC.md`、`API_REQUEST_DOC.md`

## 3. 架构约束

### 3.1 每端点独立

用户明确要求某个请求格式变化不能影响其他端点。继续维护时必须保持：

- 每个端点独立 DTO。
- 每个端点独立 RequestBuilder。
- 每个端点独立 Service。
- 不复用可变请求体 Map。
- 契约变化同步更新对应端点测试。

### 3.2 队列按参数快照路由

生成任务必须读取 `GenerationSpec.backendMode`，不能在执行时读取用户当前默认后端，否则用户切换设置后会改变已排队任务语义。

### 3.3 安全凭据不得进入普通存储

以下内容只允许进入 Keychain/Keystore：

- NovelAI Token。
- 网关 API Key。
- LLM API Key。

不得写入 SharedPreferences、SQLite、日志、备份 JSON、测试快照或 Git。备份层当前故意不依赖 SecureCredentialStore。

## 4. 当前已知风险与高优先级待办

用户尚未给出所有问题的逐项复现，因此下面既包含已确认限制，也包含必须优先实机验证的高风险区域。

### P0：先保证数据与请求安全

1. 验证设置页导出/导入在 Android 与 iOS 文件选择器上的真实行为。
2. 验证导入损坏 JSON、超大历史、未知字段、重复 ID 时不会破坏现有数据。
3. 备份目前不包含图片文件，只保存路径；跨设备恢复会出现失效图片路径。
4. 导入当前先保存普通设置再导入历史，不是跨仓库原子事务；中途失败可能只恢复一部分。
5. 清除全部安全凭据后，设置页现有 TextEditingController 可能仍暂时显示旧值，需刷新或清空 UI。

### P0：双后端真实契约

1. 所有 Mock 契约测试通过不等于真实服务已全部验证。
2. NovelAI 原生 V4.5 角色参考、Vibe、导演工具和订阅接口需使用真实账号逐项冒烟。
3. 网关高级字段是否完全匹配用户当前部署版本仍需实测。
4. 网关 Chat 多角色使用 system message；如网关契约调整，只改 Chat DTO/Builder/Service。
5. SSE 取消、弱网重连、429 冷却和应用切后台恢复需长时间实机验证。

### P1：移动端体验

1. 创作页高级参数较多，小屏设备可能存在滚动、键盘遮挡和信息密度问题。
2. 图片选择、蒙版编辑、大图预览和多参考图同时存在时需继续观察内存峰值。
3. 当前大图处理没有完整迁移到 Isolate，低内存设备可能卡顿或被系统终止。
4. 错误信息多数直接显示异常字符串，后续应做用户文案与开发诊断详情分离。
5. 无障碍、横屏、平板布局、字体缩放和浅色主题尚未完整验收。

### P1：历史与队列

1. 历史列表默认分页上限和超大图库性能需要压测。
2. 删除历史会删除关联图片；需要确认重复路径或未来共享文件不会被误删。
3. 导入历史路径可能指向不存在文件，应在 UI 标记“图片缺失”而不是空白失败。
4. 队列目前串行；后台执行仍受 iOS/Android 系统限制，不能承诺永久后台生图。
5. schema v2 只补强顺序迁移示例；未来每次字段变化都必须增加明确迁移测试。

### P1：LLM 与 Danbooru

1. Vision 只能依赖用户选择真正支持 `image_url` 的模型，不能通过模型名可靠自动判断。
2. LLM 输出虽有 JSON 修复，仍需防止候选池外 tag 混入最终结果。
3. Danbooru 公共端点可能限流或离线，自定义端点和错误反馈需继续完善。
4. 当前不实现 Agent 自动工具调用，这是明确产品边界，不应误加自动生图副作用。
5. Prompt 版本目前为 1；升级默认 Prompt 时不能覆盖用户自定义内容。

### P2：发布

1. Android 当前本地 APK 未配置私有 keystore，使用 debug key 签名，只适合侧载测试。
2. iOS `NovelAICanvas.ipa` 必须在 Codemagic macOS Runner 实际构建并在 TrollStore 安装验证。
3. TrollStore IPA 不适用于 App Store、TestFlight 或普通安装。
4. 应补充真实应用图标、启动图和正式截图。
5. GitHub Release、Tag 和 SHA-256 自动发布尚未跑过首轮真实流水线。

## 5. Android 构建特殊问题

Windows 本机项目在 E 盘，Pub Cache 在 C 盘。Kotlin 增量编译会输出大量“different roots”缓存异常，但最终可能回退为非增量编译并成功。可靠的清理构建命令使用 CMD 语法：

```bat
set "JAVA_HOME=D:\Android\Android Studio\jbr" && set "PATH=D:\Android\Android Studio\jbr\bin;%PATH%" && android\gradlew.bat --stop && if exist build rmdir /s /q build && flutter pub get && flutter build apk --release
```

Flutter 实际使用 JDK：`D:\Android\Android Studio\jbr`。

`file_picker` 使用 `12.0.0-beta`，原因是：

- 10.x 与 `wakelock_plus 1.6.1` 的 win32 主版本冲突。
- 3.x 虽能解析依赖，但旧 Android 插件缺少 AGP namespace，无法构建。
- 12 beta 可构建，但属于预发布依赖，后续应在稳定版支持 win32 6 后切回稳定约束。

## 6. 发布配置

### Android

- 本地构建：`flutter build apk --release`
- 私有签名模板：`android/key.properties.example`
- 正式 keystore 和 `android/key.properties` 已加入 `.gitignore`
- Actions Secrets：
  - `ANDROID_KEYSTORE_BASE64`
  - `ANDROID_STORE_PASSWORD`
  - `ANDROID_KEY_PASSWORD`
  - `ANDROID_KEY_ALIAS`

### iOS TrollStore

- 第三方构建平台：Codemagic
- 配置：`codemagic.yaml`
- 构建：`flutter build ios --release --no-codesign`
- 固定产物：`NovelAICanvas.ipa`
- 打包结构：`Payload/Runner.app`

## 7. 建议的下一轮执行顺序

1. 让用户列出 Android 实机发现的问题，要求每项包含页面、操作步骤、预期、实际、截图或日志。
2. 优先修 P0：崩溃、数据丢失、请求错误、密钥泄漏、无法生成或无法保存。
3. 对原生与网关分别做真实服务冒烟矩阵，不要只依赖 Mock。
4. 增加设置备份、缺失图片历史、队列恢复和主要页面 Widget 测试。
5. 在 Codemagic 连接本仓库并运行 iOS 工作流，下载 IPA 后在 TrollStore 设备验证。
6. 修完实机问题后再打 `v1.0.0` Tag；当前版本不建议直接标记正式稳定版。

## 8. 提交与验证规则

每次交付前至少执行：

```shell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
```

提交信息继续使用中文标题和完整中文正文，正文需列明功能、兼容性、测试和构建结果。

## 9. 当前产物

- 本地 APK：`release/NovelAICanvas-android.apk`
- SHA-256：`12bdb5239764bb6cdbc34e8d6fd7145756cd42d1ac58e56e685006cd3642ddb1`
- 该 APK 是构建产物，不建议长期提交到 Git；如果仓库体积需要控制，可改由 GitHub Actions Artifact/Release 托管。
