/// Emotion presets accepted by the NovelAI director `emotion` tool.
///
/// The UI offers Chinese labels while the upstream API only understands the
/// English values, so the mapping lives in the domain layer next to the other
/// generation vocabulary instead of inside a controller.
enum DirectorEmotion {
  neutral('中性', 'neutral'),
  happy('开心', 'happy'),
  sad('悲伤', 'sad'),
  angry('生气', 'angry'),
  scared('害怕', 'scared'),
  surprised('惊讶', 'surprised'),
  tired('疲惫', 'tired'),
  excited('兴奋', 'excited'),
  nervous('紧张', 'nervous'),
  thinking('思考', 'thinking'),
  confused('困惑', 'confused'),
  shy('害羞', 'shy'),
  disgusted('厌恶', 'disgusted'),
  smug('得意', 'smug'),
  bored('无聊', 'bored'),
  laughing('大笑', 'laughing'),
  irritated('烦躁', 'irritated'),
  aroused('脸红', 'aroused'),
  embarrassed('尴尬', 'embarrassed'),
  worried('担忧', 'worried'),
  love('爱意', 'love'),
  determined('坚定', 'determined'),
  hurt('受伤', 'hurt'),
  playful('俏皮', 'playful');

  const DirectorEmotion(this.label, this.value);

  /// Chinese label shown in the picker.
  final String label;

  /// English value sent to the upstream director endpoint.
  final String value;
}
