abstract interface class AgentToolRegistry {
  Iterable<String> get registeredToolNames;
}

class EmptyAgentToolRegistry implements AgentToolRegistry {
  const EmptyAgentToolRegistry();

  @override
  Iterable<String> get registeredToolNames => const [];
}
