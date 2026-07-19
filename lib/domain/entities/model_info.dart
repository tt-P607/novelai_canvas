import 'package:equatable/equatable.dart';

class ModelInfo extends Equatable {
  const ModelInfo({required this.id, this.object, this.created, this.ownedBy});

  final String id;
  final String? object;
  final int? created;
  final String? ownedBy;

  @override
  List<Object?> get props => [id, object, created, ownedBy];
}
