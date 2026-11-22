import 'package:equatable/equatable.dart';

/// Estado de consumo e limites do Assistente IA controlado no backend.
class AiQuotaStatus extends Equatable {
  const AiQuotaStatus({
    this.dailyLimit = 60,
    this.dailyUsed = 0,
    this.remainingToday = 60,
    this.burstLimit = 12,
    this.burstWindowSeconds = 300,
  });

  factory AiQuotaStatus.fromJson(Map<String, dynamic> json) {
    final dailyLimit = (json['dailyLimit'] as num?)?.toInt() ?? 60;
    final dailyUsed = (json['dailyUsed'] as num?)?.toInt() ?? 0;
    final remaining = (json['remainingToday'] as num?)?.toInt() ??
        (dailyLimit - dailyUsed).clamp(0, dailyLimit);
    return AiQuotaStatus(
      dailyLimit: dailyLimit,
      dailyUsed: dailyUsed,
      remainingToday: remaining,
      burstLimit: (json['burstLimit'] as num?)?.toInt() ?? 12,
      burstWindowSeconds:
          (json['burstWindowSeconds'] as num?)?.toInt() ?? 300,
    );
  }

  final int dailyLimit;
  final int dailyUsed;
  final int remainingToday;
  final int burstLimit;
  final int burstWindowSeconds;

  double get usedRatio =>
      dailyLimit > 0 ? (dailyUsed / dailyLimit).clamp(0.0, 1.0) : 0.0;

  @override
  List<Object?> get props => [
        dailyLimit,
        dailyUsed,
        remainingToday,
        burstLimit,
        burstWindowSeconds,
      ];
}
