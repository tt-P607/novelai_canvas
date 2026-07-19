# API 能力矩阵

| 能力 | NovelAI 原生 | OpenAI 兼容网关 |
|---|---|---|
| 文生图 | 支持 | Chat / generations |
| 图生图 | 支持 | `/v1/images/img2img` |
| 局部重绘 | 支持 | inpainting / edits |
| 流式 | 中间帧 + 最终帧 | 最终结果 SSE |
| Vibe | encode-vibe 后生成 | vibe-transfer |
| V4.5 角色参考 | 支持 | 依网关能力降级 |
| 多角色 | V4 captions + characterPrompts | Chat system 结构 |
| 4× 放大 | 支持 | upscale |
| 标签建议 | 支持 | suggest-tags |
| 六种导演工具 | 支持 | 六个独立端点 |
| 用户/订阅 | 支持 | 不适用 |

每个公开端点均保持独立 DTO、RequestBuilder 与 Service。请求格式变化应只修改对应端点模块及契约测试。
