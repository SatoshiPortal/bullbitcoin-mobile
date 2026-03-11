import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';

class MempoolServerModel {
  final String url;
  final bool isTestnet;
  final bool isLiquid;
  final bool isCustom;
  final bool enableSsl;

  MempoolServerModel({
    required this.url,
    required this.isTestnet,
    required this.isLiquid,
    required this.isCustom,
    this.enableSsl = true,
  });

  factory MempoolServerModel.fromSqlite(MempoolServerRow row) {
    return MempoolServerModel(
      url: row.url,
      isTestnet: row.isTestnet,
      isLiquid: row.isLiquid,
      isCustom: row.isCustom,
      enableSsl: row.enableSsl,
    );
  }

  MempoolServerRow toSqlite() {
    return MempoolServerRow(
      url: url,
      isTestnet: isTestnet,
      isLiquid: isLiquid,
      isCustom: isCustom,
      enableSsl: enableSsl,
    );
  }

  factory MempoolServerModel.fromEntity(MempoolServer entity) {
    return MempoolServerModel(
      url: entity.url,
      isTestnet: entity.isTestnet,
      isLiquid: entity.isLiquid,
      isCustom: entity.isCustom,
      enableSsl: entity.enableSsl,
    );
  }

  MempoolServer toEntity() {
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    return MempoolServer.existing(
      url: url,
      network: network,
      isCustom: isCustom,
      enableSsl: enableSsl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MempoolServerModel &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          isTestnet == other.isTestnet &&
          isLiquid == other.isLiquid &&
          isCustom == other.isCustom &&
          enableSsl == other.enableSsl;

  @override
  int get hashCode =>
      url.hashCode ^
      isTestnet.hashCode ^
      isLiquid.hashCode ^
      isCustom.hashCode ^
      enableSsl.hashCode;

  @override
  String toString() =>
      'MempoolServerModel(url: $url, isTestnet: $isTestnet, isLiquid: $isLiquid, isCustom: $isCustom, enableSsl: $enableSsl)';
}
