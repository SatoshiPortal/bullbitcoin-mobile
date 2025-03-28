import 'dart:convert';


import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class ElectrumServerDatasource {
  final KeyValueStorageDatasource<String> _electrumServerStorage;

  const ElectrumServerDatasource({
    required KeyValueStorageDatasource<String> electrumServerStorage,
  }) : _electrumServerStorage = electrumServerStorage;

  Future<ElectrumServerModel?> get({required Network network}) async {
    final key = '${SettingsConstants.electrumServerKeyPrefix}${network.name}';
    final value = await _electrumServerStorage.getValue(key);
    if (value == null) {
      return null;
    }
    final model = jsonDecode(value) as Map<String, dynamic>;
    return ElectrumServerModel.fromJson(model);
  }

  Future<void> set(
    ElectrumServerModel server, {
    required Network network,
  }) async {
    final key = '${SettingsConstants.electrumServerKeyPrefix}${network.name}';
    final value = jsonEncode(server.toJson());
    await _electrumServerStorage.saveValue(key: key, value: value);
  }
}
