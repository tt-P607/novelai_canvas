enum BackendMode {
  native,
  gateway;

  String get label => switch (this) {
    BackendMode.native => 'NovelAI 原生接口',
    BackendMode.gateway => 'OpenAI 兼容网关',
  };
}
