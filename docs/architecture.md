# 架构

## 分层

- `lib/core`：网络、依赖注入、队列、存储、备份、主题与通用错误。
- `lib/domain`：实体和仓库接口，不依赖具体 Flutter 页面或 API 响应格式。
- `lib/data`：每端点独立 DTO、RequestBuilder、Service，以及 SQLite/SharedPreferences/Secure Storage 实现。
- `lib/presentation`：ChangeNotifier 控制器与 Material 3 页面。

## 双后端

NovelAI 原生 Dio 与网关 Dio 常驻，通过任务参数快照中的 backendMode 路由。排队任务不会因用户切换默认后端而改变请求语义。

## 持久化

SQLite 保存完整 GenerationSpec JSON 快照与检索字段；图片保存在应用支持目录。数据库使用顺序 schemaVersion 迁移，并在启动时将 running 任务恢复为 interrupted。

## 安全

NovelAI Token、网关 Key 与 LLM Key 仅保存在 Keychain/Keystore。普通设置、日志与备份不包含明文凭据。

## 备份

备份格式 `novelai-canvas-backup` 当前版本为 1。导入通过领域实体解析并写入当前 schema，不直接替换数据库文件；同 ID 历史默认保留本机记录。
