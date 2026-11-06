import 'package:bb_mobile/features/electrum_settings/domain/electrum_server.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
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
    return ElectrumServer.existing(
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
      network: ElectrumServerNetwork.fromStorageName(row.network),
      priority: row.priority,
      isCustom: row.isCustom,
    );
  }

  ElectrumServerRow toSqlite() {
    return ElectrumServerRow(
      url: url,
      network: network.storageName,
      priority: priority,
      isCustom: isCustom,
    );
  }
}
