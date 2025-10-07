import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';

class ElectrumServerModel {
  final String url;
  final ElectrumServerNetwork network;
  final int priority;
  final bool isCustom;

  ElectrumServerModel({
    required this.url,
    required this.network,
    this.priority = 0,
    this.isCustom = false,
  });

  ElectrumServer toEntity() {
    return ElectrumServer(
      url: url,
      network: network,
      priority: priority,
      isCustom: isCustom,
    );
  }

  factory ElectrumServerModel.fromEntity(ElectrumServer entity) {
    return ElectrumServerModel(
      url: entity.url,
      network: entity.network,
      priority: entity.priority,
      isCustom: entity.isCustom,
    );
  }

  factory ElectrumServerModel.fromSqlite(ElectrumServerRow row) {
    return ElectrumServerModel(
      url: row.url,
      network: ElectrumServerNetwork.fromEnvironment(
        isTestnet: row.isTestnet,
        isLiquid: row.isLiquid,
      ),
      priority: row.priority,
      isCustom: row.isCustom,
    );
  }

  ElectrumServerRow toSqlite() {
    return ElectrumServerRow(
      url: url,
      isTestnet: network.isTestnet,
      isLiquid: network.isLiquid,
      priority: priority,
      isCustom: isCustom,
    );
  }
}
