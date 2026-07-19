# 后续 AI 开发与发布完整流程

本文是 NovelAI Canvas · 绘境的持久化操作手册。后续接手的 AI 或开发者应先阅读本文，再阅读 [`handover.md`](handover.md) 与两份 API 契约文档，避免重复踩坑或破坏既有模块边界。

## 1. 项目定位与固定信息

- Flutter 项目根目录：`novelai_canvas`
- Android/iOS 包名：`com.elysia.novelaicanvas`
- 产品名：NovelAI Canvas · 绘境
- Git 远端：`https://github.com/tt-P607/novelai_canvas.git`
- 主分支：`main`
- TrollStore IPA 固定名：`NovelAICanvas.ipa`
- Android Release 默认产物：`build/app/outputs/flutter-apk/app-release.apk`
- 工作区上级 API 文档：`NOVELAI_API_DOC.md`、`API_REQUEST_DOC.md`

## 2. 每次接手前的恢复流程

### 2.1 先确认真实状态

依次检查：

1. 阅读本文。
2. 阅读 `docs/handover.md`。
3. 阅读 `docs/known-issues.md`。
4. 阅读工作区上级的两份 API 文档。
5. 执行 `git status --short`。
6. 执行 `git log -5 --oneline`。
7. 如果存在未提交修改，执行 `git diff --stat` 和 `git diff --check`。
8. 不要根据 VS Code 残留标签判断文件是否仍存在，以 Git 状态为准。

### 2.2 当前稳定基线

截至 2026-07-19：

- 最新功能提交：`ae2213a fix: 修正生成交互与工具请求`
- `flutter analyze`：无问题。
- `flutter test`：30 项全部通过。
- Android Release APK 构建成功。
- 最新 APK 大小：58,516,349 字节，约 55.8 MB。
- 最新 APK SHA-256：`aeb4c22e4e44b6856a0e4002e533a410c6fe15b01cac62d3e23b0a1f6f486b77`

如果 Git 历史已经前进，以新提交和新验证结果为准，并同步更新本文。

## 3. 不得破坏的架构约束

### 3.1 请求层必须按端点独立

用户要求某一个请求格式变化不能影响其他端点。任何 API 修改都必须遵守：

- 每个端点独立 DTO。
- 每个端点独立 RequestBuilder。
- 每个端点独立 Service。
- 不共享可变请求 Map。
- 修改契约时只改对应端点及其测试。

主要目录：

- 原生 API：`lib/data/api/native`
- 网关 API：`lib/data/api/gateway`
- 原生生成参数：`lib/data/api/native/dto/native_generation_parameters_dto.dart`
- 统一生成路由：`lib/data/repositories/generation_repository_impl.dart`

### 3.2 队列必须按任务快照路由

生成任务执行时必须读取 `GenerationSpec.backendMode`，不得读取用户当前默认后端。原因是用户可能在任务排队后切换后端，已排队任务仍必须保持提交时语义。

### 3.3 敏感凭据只允许进入安全存储

以下内容只能进入 Keychain/Keystore：

- NovelAI Token
- 网关 API Key
- LLM API Key

禁止写入：

- SharedPreferences
- SQLite
- 日志
- 备份 JSON
- 测试黄金文件
- Git 仓库

### 3.4 UI 与业务逻辑分离

页面通过 Controller 和领域实体操作业务，不允许在 Widget 中直接发网络请求或访问 SQLite。可复用视觉组件放入 `lib/presentation/widgets`。

多角色点位组件示例：`lib/presentation/widgets/character_position_grid.dart`。以后修改点位视觉时，应优先只改组件，不改生成仓库。

## 4. 当前关键行为说明

### 4.1 流式生成

- NovelAI 原生文生图、图生图、局部重绘均支持渐进式中间预览。
- 原生流式端点为 `/ai/generate-image-stream`。
- 普通生成请求完整保留 `generate`、`img2img` 或 `infill` action，只在 `parameters` 中追加 `stream: sse`。
- 网关的 Chat `stream=true` 只是最终结果 SSE 包装，不是 NovelAI 中间帧。
- 当前创作页的渐进式开关只会在原生后端任务快照中生效，不能把该状态注入网关任务。

### 4.2 导演工具

原生 `/ai/augment-image` 推荐 JSON 请求：

- 所有工具发送 `req_type`、`image`、`width`、`height`。
- 只有 `colorize` 和 `emotion` 发送 `prompt`、`defry`。
- `declutter`、`bg-removal`、`lineart`、`sketch` 不应发送无意义的空 `prompt` 和 `defry`。

网关六个导演工具保持六个独立端点和 Service。

### 4.3 局部重绘

- 默认开启 `add_original_image` 边缘融合。
- 提示词描述整张画面，而不是只描述重绘区域。
- 遮罩要求白色为重绘、黑色为保留。
- 蒙版画板保存时输出黑白 PNG，并对齐到 8×8 latent 网格要求。
- 画板预览使用不透明颜色，避免不同笔画重叠后透明度叠加产生错误视觉。

### 4.4 画幅

官方预设：

- 832×1216 竖图
- 1024×1024 方图
- 1216×832 横图
- 1024×1536 大竖图
- 1536×1024 大横图

同时允许自定义宽高：

- 范围 64–1600。
- 自动对齐到最接近的 64 倍数。
- 超过 1,048,576 像素可能消耗 Anlas。
- 不得把界面重新限制为只有三个固定尺寸。

### 4.5 多角色坐标

当前采用 5×5 网格，坐标为 0.1、0.3、0.5、0.7、0.9。界面使用直观网格选择，不使用包含 A1–E5 的超长下拉菜单。

### 4.6 提示词助手

- 使用一个 OpenAI 兼容模型配置，类似 Chatbox。
- 同一个模型负责关键词提取、提示词整理、JSON 修复和可选识图。
- 当用户使用识图时，该模型必须支持 OpenAI `image_url` 多模态消息。
- 助手默认从创作页弹出面板。
- 面板可全屏打开。
- 面板可缩小为悬浮球。
- 用户确认后只回填提示词草稿，不自动提交生成。
- LLM 连接、模型、Danbooru 和四套 Prompt 均在设置页管理，不在助手操作面板重复放配置入口。

## 5. 开发修改标准流程

### 5.1 修改前

1. 根据问题定位端点、领域实体、Controller 和 UI。
2. 新区域探索先做语义搜索，再读取精确文件。
3. 对照最新 API 文档，不依赖旧记忆。
4. 确认修改是否影响历史快照兼容性。
5. 确认是否需要 SQLite migration。

### 5.2 修改中

- 现有文件使用精确局部修改，避免无必要整文件重写。
- 新可复用 UI 建立独立 Widget。
- 错误展示优先显示 `AppException.message`，不要把完整 Dio 异常文本直接放到红色卡片。
- 新字段必须提供旧数据默认值。
- 新 API 字段必须补 RequestBuilder 契约测试。
- 不要创建会泄漏 Token/Key 的调试日志。

### 5.3 修改后验证

Windows 当前命令宿主通常按 CMD 解释。不要用 PowerShell 的 `$env:`，也不要用分号串联 Flutter 命令。

依次执行：

```bat
dart format lib test
flutter analyze
flutter test
```

严格格式检查可使用：

```bat
dart format --output=none --set-exit-if-changed lib test
```

然后检查：

```bat
git diff --check
git status --short
git diff --stat
```

## 6. Git 提交与推送流程

提交必须使用中文标题和完整中文正文。正文至少说明：

1. 修复或实现了什么。
2. API/历史兼容性如何处理。
3. UI 或数据行为如何变化。
4. 执行了哪些测试和构建。

示例：

```bat
git add lib test docs
git commit -m "fix: 修正生成交互与工具请求" -m "说明第一组修改。" -m "说明兼容性和测试结果。"
git push origin main
```

注意：

- 工具环境可能把 `;` 当普通参数，不要使用 `command1; command2`。
- 当前 GitHub PAT 曾缺少 `workflow` scope，修改 `.github/workflows` 可能被拒绝。
- 当前 iOS 云构建使用 Codemagic，不需要为了构建 IPA重新加入 GitHub Actions workflow。

## 7. Android Release 完整流程

### 7.1 环境

- Windows 10
- Flutter 3.41.8 stable
- Dart 3.11.5
- Android Studio JDK 21：`D:\Android\Android Studio\jbr`

### 7.2 普通构建

在项目根目录执行：

```bat
set "JAVA_HOME=D:\Android\Android Studio\jbr" && set "PATH=D:\Android\Android Studio\jbr\bin;%PATH%" && flutter build apk --release
```

产物：

```text
build\app\outputs\flutter-apk\app-release.apk
```

如果存在 `android/key.properties`，使用正式 keystore；不存在时回退到 debug key 生成可侧载 Release APK。

### 7.3 缓存损坏时的清理构建

项目位于 E 盘，Pub Cache 通常位于 C 盘，Kotlin 增量缓存可能报 `different roots`。不要反复执行同一个失败构建，应清理：

```bat
set "JAVA_HOME=D:\Android\Android Studio\jbr" && set "PATH=D:\Android\Android Studio\jbr\bin;%PATH%" && android\gradlew.bat --stop && if exist build rmdir /s /q build && flutter pub get && flutter build apk --release
```

必要时再执行 `flutter clean`，但会增加完整重建时间。

### 7.4 APK 校验

查看大小和 SHA-256：

```bat
for %I in (build\app\outputs\flutter-apk\app-release.apk) do @echo SIZE_BYTES=%~zI
certutil -hashfile build\app\outputs\flutter-apk\app-release.apk SHA256
```

2026-07-19 最新产物：

- 路径：`build/app/outputs/flutter-apk/app-release.apk`
- 大小：58,516,349 字节
- Flutter 输出：55.8 MB
- SHA-256：`aeb4c22e4e44b6856a0e4002e533a410c6fe15b01cac62d3e23b0a1f6f486b77`

## 8. Android 签名

正式发布前复制 `android/key.properties.example` 为 `android/key.properties`，填写：

```properties
storePassword=
keyPassword=
keyAlias=
storeFile=release-keystore.jks
```

keystore 放在 `android/app` 或使用正确相对路径。以下内容禁止提交：

- `android/key.properties`
- `*.jks`
- `*.keystore`
- 密码或 Base64 keystore

## 9. Codemagic TrollStore IPA 流程

### 9.1 仓库结构关键点

Codemagic 连接的是独立仓库 `tt-P607/novelai_canvas`。克隆后当前目录已经是 Flutter 项目根目录，因此：

- 不要执行 `cd novelai_canvas`。
- 不要把 artifact 写成 `novelai_canvas/NovelAICanvas.ipa`。
- 直接执行根目录的 Flutter 命令。

### 9.2 当前工作流

配置文件：`codemagic.yaml`

核心流程：

```shell
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
mkdir -p Payload
cp -R build/ios/iphoneos/Runner.app Payload/
ditto -c -k --sequesterRsrc --keepParent Payload NovelAICanvas.ipa
rm -rf Payload
shasum -a 256 NovelAICanvas.ipa > NovelAICanvas.ipa.sha256
```

产物：

- `NovelAICanvas.ipa`
- `NovelAICanvas.ipa.sha256`

### 9.3 iOS 最低版本

`file_picker 12 beta` 要求 iOS 14。项目的 `ios/Runner.xcodeproj/project.pbxproj` 必须保持：

```text
IPHONEOS_DEPLOYMENT_TARGET = 14.0;
```

如果 Codemagic 报 `file-picker requires minimum platform version 14.0`，说明构建使用了旧提交或 Deployment Target 被回退。

### 9.4 Codemagic 操作

1. 在 Codemagic 连接 GitHub 仓库 `tt-P607/novelai_canvas`。
2. 确认读取仓库根目录 `codemagic.yaml`。
3. 选择 workflow：`NovelAI Canvas iOS IPA (TrollStore)`。
4. 分支选择 `main`。
5. 确认构建详情中的 Commit 是预期最新提交。
6. 点击 Start new build。
7. 依次查看 Dependencies、Analyze and test、Build unsigned iOS app、Package TrollStore IPA。
8. 从 Artifacts 下载 IPA 与 SHA-256 文件。
9. 在 TrollStore 设备安装并做冒烟测试。

### 9.5 iOS 失败排查原则

- 必须展开失败步骤并读取完整 Xcode 错误。
- 不要只根据红色步骤标题猜测。
- 先确认实际 Commit，避免修复已推送但构建仍使用旧提交。
- 不要再次错误加入 `cd novelai_canvas`。
- Deployment Target、Swift Package、CocoaPods、Xcode 签名错误分别处理，不要混为一谈。

## 10. 依赖特殊说明

### `file_picker`

当前使用 12 beta，原因：

- 10.x 与 `wakelock_plus 1.6.1` 的 `win32` 主版本约束冲突。
- 3.x 缺少现代 Android Gradle Plugin 所需 namespace。
- 12 beta 可在现代 Android 构建，但要求 iOS 14。

当前单文件 JSON 选择 API：

```dart
final selection = await FilePicker.pickFile(
  type: FileType.custom,
  allowedExtensions: const ['json'],
);
final path = selection?.path;
```

升级依赖后必须重新验证 Android 与 iOS。

## 11. 测试矩阵

每次 API 或核心流程修改至少覆盖：

- 原生 RequestBuilder 黄金请求。
- 网关 RequestBuilder 请求字段。
- SSE intermediate/final 解析。
- URL、base64、ZIP 图片解码。
- 导演工具可选字段。
- 任务 JSON 快照往返。
- SQLite 历史与迁移。
- 队列取消、重试和恢复。
- 备份不包含任何安全凭据。
- 助手 OpenAI 消息与 Danbooru 解析。
- 首次启动 Widget 测试。

真实服务仍需分别对原生和网关做冒烟，Mock 通过不代表线上契约一定正确。

## 12. 实机验收建议

Android APK 或 iOS IPA 安装后依次验证：

1. 原生后端连接与 Token。
2. 网关地址和 Key。
3. 文生图普通生成。
4. 文生图渐进式预览。
5. 图生图普通和渐进式。
6. 局部重绘、蒙版多笔绘制、边缘融合。
7. 五个官方画幅和自定义画幅。
8. Vibe、多角色网格、角色参考。
9. 六种导演工具。
10. 放大和标签建议。
11. 提示词助手面板、全屏、悬浮球、单模型识图。
12. 历史、收藏、搜索、保存、参数复用。
13. 备份导出、导入和清除凭据。

问题反馈应包含：页面、操作步骤、预期结果、实际结果、截图、后端模式、模型、HTTP 状态和可用日志。

## 13. 常见错误与禁止重复的失败方案

| 问题 | 根因 | 正确处理 |
|---|---|---|
| `cd novelai_canvas: No such file or directory` | Codemagic 已在独立仓库根目录 | 删除额外 `cd` |
| iOS file-picker 要求 14.0 | Deployment Target 过低 | 保持 iOS 14.0 |
| Android Kotlin `different roots` | 项目与 Pub Cache 跨盘缓存 | 停 Gradle daemon、清 build、重新构建 |
| PowerShell `$env:` 无效 | 工具宿主实际按 CMD | 使用 `set "JAVA_HOME=..."` |
| `dart format lib test; flutter analyze` 被错误解析 | 分号未作为命令分隔符 | 用 `&&` 或分开调用 |
| GitHub 拒绝 workflow 修改 | PAT 缺少 workflow scope | 不提交 workflow，或更新凭据后再改 |
| 导演工具 500 且请求看似合法 | 给无需引导的工具发送多余字段 | 仅上色/表情发送 prompt/defry |
| 网关模式开启流式后生成报错 | 原生 SSE 状态被错误注入网关 | 任务快照仅原生保存渐进式开关 |
| UI 多角色下拉框过长 | 25 个点位使用 Dropdown | 使用独立 5×5 网格组件 |
| Vision 要填两个模型 | 旧设置拆分文本模型和识图模型 | 统一为一个模型，识图时要求其支持多模态 |

## 14. 文档维护规则

以下情况必须更新本文与 `handover.md`：

- Flutter、Dart、JDK 或 iOS 最低版本变化。
- API 契约变化。
- 构建命令变化。
- 新的 Android/iOS 产物和 SHA-256。
- 新增数据库迁移。
- 新的高优先级已知问题。
- Codemagic 工作流变化。
- 依赖冲突解决方案变化。

本文应始终能让一个没有旧会话上下文的 AI 从零恢复项目状态、完成修改、验证、提交、Android 构建和 iOS 云构建。
