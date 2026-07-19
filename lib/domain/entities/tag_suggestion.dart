import 'package:equatable/equatable.dart';

class TagSuggestion extends Equatable {
  const TagSuggestion({
    required this.tag,
    required this.count,
    required this.confidence,
  });

  final String tag;
  final int count;
  final double confidence;

  @override
  List<Object?> get props => [tag, count, confidence];
}
