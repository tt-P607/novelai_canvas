import 'package:equatable/equatable.dart';

class SubscriptionInfo extends Equatable {
  const SubscriptionInfo({
    required this.tier,
    required this.active,
    this.expiresAt,
    this.perks = const {},
    this.trainingStepsLeft = const {},
    this.raw = const {},
  });

  final int tier;
  final bool active;
  final DateTime? expiresAt;
  final Map<String, Object?> perks;
  final Map<String, Object?> trainingStepsLeft;
  final Map<String, Object?> raw;

  /// Total Anlas balance = subscription allowance + purchased credits.
  /// trainingStepsLeft is NAI's internal name for the Anlas ledger.
  int get anlas {
    final fixed =
        (trainingStepsLeft['fixedTrainingStepsLeft'] as num?)?.toInt() ?? 0;
    final purchased =
        (trainingStepsLeft['purchasedTrainingSteps'] as num?)?.toInt() ?? 0;
    return fixed + purchased;
  }

  String get tierName => switch (tier) {
    1 => 'Tablet',
    2 => 'Scroll',
    3 => 'Opus',
    _ => 'Paper',
  };

  @override
  List<Object?> get props => [
    tier,
    active,
    expiresAt,
    perks,
    trainingStepsLeft,
    raw,
  ];
}
