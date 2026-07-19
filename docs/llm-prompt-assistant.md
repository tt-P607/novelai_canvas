# LLM 提示词助手

助手使用独立 OpenAI 兼容 Provider，与生图后端配置分离。

## 流程

1. 将自然语言描述提取为角色、场景、风格和 NSFW 关键词。
2. 查询 Danbooru search，并按角色调用 related。
3. 展示真实 tag、中文名、分类、热度、分数、wiki、来源和 NSFW 元数据。
4. 仅基于原始描述与候选池整理全局正向、负向和角色提示词。
5. 非法 JSON 使用独立 JSON 修复 Prompt 二次修复。
6. 用户确认后回填创作页，不自动提交生成任务。

## Vision

图片以 OpenAI `image_url` data URI 发送。配置的 Vision 模型必须真实支持多模态图片输入；普通文本模型不能识图。

## 可编辑 Prompt

关键词提取、提示词整理、Vision 识图、JSON 修复四套 Prompt 均带版本号，可单独编辑和恢复默认。Prompt 会进入非敏感备份；LLM API Key 不会导出。

## Agent 边界

当前仅保留空的 AgentToolRegistry 扩展接口，不注册自动生图、放大、导演工具、Pixiv 或其他副作用工具。
