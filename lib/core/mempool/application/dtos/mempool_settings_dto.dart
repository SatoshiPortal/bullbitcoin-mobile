import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';

class MempoolSettingsDto {
  final String network;
  final bool useForFeeEstimation;

  MempoolSettingsDto({
    required this.network,
    required this.useForFeeEstimation,
  });

  factory MempoolSettingsDto.fromEntity(MempoolSettings entity) {
    return MempoolSettingsDto(
      network: entity.network.networkString,
      useForFeeEstimation: entity.useForFeeEstimation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolSettingsDto &&
          runtimeType == other.runtimeType &&
          network == other.network &&
          useForFeeEstimation == other.useForFeeEstimation;

  @override
  int get hashCode => network.hashCode ^ useForFeeEstimation.hashCode;

  @override
  String toString() =>
      'MempoolSettingsDto(network: $network, useForFeeEstimation: $useForFeeEstimation)';
}
