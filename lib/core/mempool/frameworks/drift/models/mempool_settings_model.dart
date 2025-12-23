import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';

class MempoolSettingsModel {
  final String network;
  final bool useForFeeEstimation;

  MempoolSettingsModel({
    required this.network,
    required this.useForFeeEstimation,
  });

  factory MempoolSettingsModel.fromSqlite(MempoolSettingsRow row) {
    return MempoolSettingsModel(
      network: row.network,
      useForFeeEstimation: row.useForFeeEstimation,
    );
  }

  MempoolSettingsRow toSqlite() {
    return MempoolSettingsRow(
      network: network,
      useForFeeEstimation: useForFeeEstimation,
    );
  }

  factory MempoolSettingsModel.fromEntity(MempoolSettings entity) {
    return MempoolSettingsModel(
      network: entity.network.networkString,
      useForFeeEstimation: entity.useForFeeEstimation,
    );
  }

  MempoolSettings toEntity() {
    final networkEnum = MempoolServerNetwork.fromString(network);

    return MempoolSettings.existing(
      network: networkEnum,
      useForFeeEstimation: useForFeeEstimation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolSettingsModel &&
          runtimeType == other.runtimeType &&
          network == other.network &&
          useForFeeEstimation == other.useForFeeEstimation;

  @override
  int get hashCode => network.hashCode ^ useForFeeEstimation.hashCode;

  @override
  String toString() =>
      'MempoolSettingsModel(network: $network, useForFeeEstimation: $useForFeeEstimation)';
}
