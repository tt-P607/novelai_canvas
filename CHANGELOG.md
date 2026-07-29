# Changelog

## 1.15.8 - 2026-07-29

- 画幅自动对齐 64 像素：[`updateSize`](novelai_canvas/lib/presentation/controllers/generation_controller.dart:368) 和 `_adoptSourceImageSize` 统一走 `_align64`，预设选择、源图导入和自定义输入全部自动对齐到 64 的倍数。上传非标准尺寸图片进行图生图/局部重绘时，画幅不再出现静默空响应问题。
- 删除标签建议功能：移除 `TagSuggestion` 实体、原生与网关的 suggest-tags / annotate-image 服务、DTO、请求构建器及依赖注入注册。
- 图像工具新增压缩画幅工具：纯客户端操作，不消耗 Anlas、不走网络。提供两种模式：**对齐 64**——仅对齐到最近 64 像素倍数；**压到免费**——等比缩放到不超过 1,048,576 像素（Opus 免费范围上限）的 64 对齐尺寸。新增 [`CompressMode`](novelai_canvas/lib/domain/repositories/image_tools_repository.dart:7) 枚举。

## 1.15.7 - 2026-07-29

- 流式生成改回走 Chat SSE 端点：new-api 等 Go 代理不支持 `/v1/images/generations` 的 `stream: true`，但原生支持 `/v1/chat/completions` 的 SSE 透传。流式虽然没有渐进式预览（只有最终结果），但能可靠工作。
- 删除不再使用的 `GatewayImageStreamService`、`GatewayTextToImageRequestDto` 和相关依赖注入。
- 修复流式 SSE 事件处理：先处理 content 再检查 finished，避免同时携带 content 和 finish_reason 的事件被跳过。

## 1.15.6 - 2026-07-29

- 适配网关流式错误事件：当上游 SSE 流中途出错时，网关会追加 `{"event_type":"error","message":"..."}` 事件。客户端 [`NativeStreamEventDto`](novelai_canvas/lib/data/api/native/dto/native_stream_dto.dart:32) 新增 `isError` / `errorMessage`，流式服务在收到 error 事件时抛出异常而非静默忽略。

## 1.15.5 - 2026-07-29

- 修复局部重绘输出纯黑：遮罩从 RGBA（4 通道，alpha=255）改为 RGB（3 通道）。网关 `build_mask` 对 RGBA 图片取 alpha 通道，全不透明 alpha=255 被解释为全图重绘，导致 NovelAI 上游行为异常。RGB 模式让网关走灰度分支，正确使用黑白值区分重绘/保留区域。

## 1.15.4 - 2026-07-29

- 修复 seed 超限：随机种子范围从 `0x7fffffff`（2,147,483,647）缩小到 `1,000,000,000`（≤ 999,999,999），匹配网关 Pydantic 验证上限。同时修复批量生成中自动随机种子的相同问题。

## 1.15.3 - 2026-07-29

- 紧急修复：Image 端点（图生图/局部重绘/导演工具/放大/Vibe/文生图流式）的 `response_format` 改回纯字符串 `"b64_json"`。new-api 的 Go 代理对 `/v1/images/generations` 要求纯字符串（DALL-E 惯例），对 `/v1/chat/completions` 要求对象 `{"type":"..."}` —— 两个端点类型不同。上版本统一改成对象导致所有 Image 请求被 Go 代理拒绝并返回 500 `"cannot unmarshal object into ...ResponseFormat of type string"`。
- Chat 端点保持对象格式 `{"type": "b64_json"}` 不变。

## 1.15.2 - 2026-07-28

- 修复 OpenAI 兼容文生图流式生成只有最终结果的问题：流式请求改走 `/v1/images/generations`，恢复 NovelAI intermediate/final 渐进预览。
- 新增独立网关文生图 DTO，流式请求完整保留步数、种子、负面提示词、质量预设和多人物参数。
- 图生图、局部重绘、导演工具、放大与 Vibe 请求统一使用对象格式 `response_format`，兼容 new-api 等严格 OpenAI 代理，避免请求在到达网关前返回 500。
- 增加网关流式路由、渐进帧解析和请求字段回归测试。

## 1.15.0 - 2026-07-28

- 网关路由从 `model` 字段改为 `extra` 字段：扩展功能（放大/导演工具）通过 `extra` 标识触发，`model` 始终填标准模型名。
  - 导演工具 builder 发 `model` + `extra: "director-xxx"`，不再用 `model: "director-xxx"`。
  - 放大 builder 发 `model` + `extra: "upscale"`，路径改走 `/v1/images/generations`。
  - 图生图/局部重绘不提供 `extra`，靠 `image`/`mask` 字段路由。

## 1.14.2 - 2026-07-28

- 导演工具改走统一端点 `/v1/images/generations` + `model: "director-xxx"`，不再用专用路径。
- 图生图与局部重绘的 `image`/`mask` 字段改为发送纯 base64，去掉 `data:image/*;base64,` 前缀。
- 删除无调用的 `_readDataUri` 和 `_mimeTypeFor`。

## 1.14.1 - 2026-07-28

- 修复网关图生图与局部重绘 HTTP 500 根因：`quality` 字段（bool）被 newapi 的 Go 结构体定义为 string 类型而拒绝。改用 `qualityToggle` 字段名，绕过 newapi 对 OpenAI 标准字段 `quality`（DALL-E 里是 `"standard"`/`"hd"` 字符串）的类型校验，网关后端仍能正确识别。

## 1.14.0 - 2026-07-28

- 网关改为统一端点方案：所有图片功能走 `/v1/images/generations`，靠 `model` 字段和请求体字段（`prompt`/`image`/`mask`）自动路由。
  - 客户端图生图与局部重绘的非流式和流式路径全部改走 `/v1/images/generations`。
  - 网关根据 `image`/`mask` 字段存在与否自动区分文生图、图生图、局部重绘，客户端 DTO 和 builder 无需改动。
  - 局部重绘遮罩保持 NovelAI 原生格式（白色=重绘，黑色=保留），与网关接受格式一致。
  - 流式通过 `stream: true` 请求体参数控制，不再依赖专用端点。

## 1.13.1 - 2026-07-28

- 网关图生图与局部重绘端点回退到各自专用路径（`/v1/images/img2img`、`/v1/images/inpainting`），不再走临时 `/v1/images/edits` 兼容端点：网关已确定「一个功能一个端点」方案，newapi 已配置转发自定义路径。
- 网关流式改用 `stream: true` 请求体参数控制，不再依赖已移除的 `-stream` 后缀专用端点。
- 移除无引用的 `GatewayEditsService`、`GatewayEditsRequestDto`（`/v1/images/edits` 方案遗留）。
- 局部重绘遮罩保持 NovelAI 原生格式（白色=重绘，黑色=保留，alpha=255），与网关 `/v1/images/inpainting` 接受的格式一致，无需 alpha 反转。

## 1.13.0 - 2026-07-28

- 流式生成不再限定文生图：图生图与局部重绘现在也支持流式预览。
  - 原生模式：`/ai/generate-image-stream` 本身按 payload 区分动作，移除客户端的 textToImage 限制即可。
  - 网关模式：新增 [`GatewayImageStreamService`](novelai_canvas/lib/data/api/gateway/services/gateway_image_stream_service.dart) 通过 `stream: true` 参数走网关图片端点，透传 NovelAI 上游 SSE 的中间预览帧。
- 提取 `_gatewayImg2ImgDto` / `_gatewayInpaintDto` 方法，让非流式与流式路径共享同一 DTO 构造，避免漂移。

## 1.12.8 - 2026-07-28

- 修复网关文生图在 newapi 等 OpenAI 标准代理上报 500 `cannot unmarshal string into ...ResponseFormat` 的根因：Chat Completions 请求的 `response_format` 从裸字符串改为 OpenAI 标准对象 `{type: "b64_json"}`。

## 1.12.7 - 2026-07-28

- 修复 v1.12.6 引入的诊断日志在流式响应（`ResponseBody`）上触发 `Converting object to an encodable object failed` 的崩溃：`GatewayChatService._truncateForLog` 与 `NetworkErrorMapper._bodyExcerpt` 对不可 JSON 序列化的响应体回退到类型名，不再掩盖原始网络错误。

## 1.12.6 - 2026-07-28

- 改进网络错误诊断：当服务器返回 5xx 但响应体无法提取结构化消息时（如反代/CDN 的 HTML 错误页），错误文案改为携带真实状态码与响应体片段，而非无信息的「网络请求失败」。
- `GatewayChatService` 在请求失败时通过 `dart:developer` 日志输出 Dio 异常类型、状态码、目标 URL 与响应体片段，便于通过 `adb logcat` 定位网关请求未到达 newapi 的根因。

## 1.12.5 - 2026-07-28

- 修复网关文生图在 newapi 等仅注册 `/v1/chat/completions` 的代理上返回 404 的问题：纯文生图统一改走 Chat Completions 端点。
- 网关流式文生图改用 Chat SSE，下载最终图片 URL 后再渲染预览（不再转发中间预览帧）。
- 移除已无引用的 `GatewayGenerationService`、`GatewayStreamService` 及对应 DTO。

## 1.12.0 - 2026-07-28

- 修复网关 base URL 含换行导致 img2img/inpainting 路径断裂的问题。
- 设置页 URL 与密钥合并为同一卡片。
- 账号等级、消耗预览与订阅提示仅在原生后端显示，OpenAI 模式隐藏。
- 网关新增 `/v1/images/generations-stream` 流式文生图支持。
- 简化凭据存储为原生与网关独立双键，移除旧共享键兼容迁移。

## 1.11.0 - 2026-07-28

- 原生与 OpenAI 接口各自独立保存 URL 和密钥，切换后端时显示对应配置。
- 修复 OpenAI 兼容网关生图请求因 baseUrl 未注入而失败的问题。

## 1.0.0 - 2026-07-19

- 完成 NovelAI 原生与 OpenAI 兼容网关双后端全端点请求层。
- 完成文生图、图生图、局部重绘、流式预览、队列、历史和参数复用。
- 完成 Vibe、V4.5 角色参考、多角色、坐标、放大、标签和六种导演工具。
- 完成轻量 LLM 提示词助手、Danbooru 校准、Vision 与四套可编辑 Prompt。
- 增加版本化非敏感备份/恢复、SQLite v2 迁移与安全凭据清理。
- 增加 Android Release 签名配置和 Codemagic TrollStore IPA 云构建。
