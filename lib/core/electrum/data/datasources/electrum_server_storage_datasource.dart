import 'dart:convert';

import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

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

  Future<ElectrumServerModel?> getByProvider(
    ElectrumServerProvider provider, {
    required Network network,
  }) async {
    final key = switch (provider) {
      ElectrumServerProvider.bullBitcoin =>
        '${SettingsConstants.bullBitcoinElectrumServerKeyPrefix}${network.name}',
      ElectrumServerProvider.blockstream =>
        '${SettingsConstants.blockstreamElectrumServerKeyPrefix}${network.name}',
      ElectrumServerProvider.custom =>
        '${SettingsConstants.customElectrumServerKeyPrefix}${network.name}',
    };
    final value = await _electrumServerStorage.getValue(key);
    if (value == null) {
      return null;
    }
    final model = jsonDecode(value) as Map<String, dynamic>;
    return ElectrumServerModel.fromJson(model);
  }
}
