import 'dart:convert';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ElectrumServerStorageDatasource {
  final KeyValueStorageDatasource<String> _electrumServerStorage;

  const ElectrumServerStorageDatasource({
    required KeyValueStorageDatasource<String> electrumServerStorage,
  }) : _electrumServerStorage = electrumServerStorage;

  Future<void> set(ElectrumServerModel server) async {
    final network = Network.fromEnvironment(
      isTestnet: server.isTestnet,
      isLiquid: server.isLiquid,
    );
    final key = switch (server) {
      BullBitcoinElectrumServerModel _ =>
        '${SettingsConstants.bullBitcoinElectrumServerKeyPrefix}${network.name}',
      BlockstreamElectrumServerModel _ =>
        '${SettingsConstants.blockstreamElectrumServerKeyPrefix}${network.name}',
      _ => '${SettingsConstants.customElectrumServerKeyPrefix}${network.name}',
    };

    final value = jsonEncode(server.toJson());
    await _electrumServerStorage.saveValue(key: key, value: value);
  }

  /// Get a default server by preset type
  Future<ElectrumServerModel?> getDefaultServerByProvider(
    DefaultElectrumServerProvider preset, {
    required Network network,
  }) async {
    // Determine the appropriate key prefix based on preset
    final keyPrefix =
        preset == DefaultElectrumServerProvider.bullBitcoin
            ? SettingsConstants.bullBitcoinElectrumServerKeyPrefix
            : SettingsConstants.blockstreamElectrumServerKeyPrefix;

    final key = '$keyPrefix${network.name}';
    final value = await _electrumServerStorage.getValue(key);

    if (value == null) return null;

    final model = jsonDecode(value) as Map<String, dynamic>;
    return ElectrumServerModel.fromJson(model);
  }

  /// Get custom server for a specific network
  Future<ElectrumServerModel?> getCustomServer({
    required Network network,
  }) async {
    final key =
        '${SettingsConstants.customElectrumServerKeyPrefix}${network.name}';
    final value = await _electrumServerStorage.getValue(key);

    if (value == null) return null;

    final model = jsonDecode(value) as Map<String, dynamic>;
    final serverModel = ElectrumServerModel.fromJson(model);

    if (serverModel is CustomElectrumServerModel) {
      return serverModel;
    }

    return null;
  }

  Future<ElectrumServerModel> getPrioritizedServer({
    required Network network,
  }) async {
    final List<ElectrumServerModel> servers = [];

    // Get custom server if available
    final customServer = await getCustomServer(network: network);
    if (customServer != null &&
        customServer.isActive &&
        customServer.url.isNotEmpty) {
      return customServer;
    }

    // Get BullBitcoin server (priority 1)
    final bullBitcoin = await getDefaultServerByProvider(
      DefaultElectrumServerProvider.bullBitcoin,
      network: network,
    );
    if (bullBitcoin != null) {
      servers.add(bullBitcoin);
    }

    // Get Blockstream server (priority 2)
    final blockstream = await getDefaultServerByProvider(
      DefaultElectrumServerProvider.blockstream,
      network: network,
    );
    if (blockstream != null) {
      servers.add(blockstream);
    }
    if (servers.isEmpty) {
      return ElectrumServerModel.bullBitcoin(isTestnet: false, isLiquid: false);
    }
    // Sort servers by priority
    servers.sort((a, b) => a.priority.compareTo(b.priority));
    return servers.first;
  }
}
