import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/electrum_server_model.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_utils/constants.dart';

abstract class ElectrumServerDataSource {
  Future<ElectrumServerModel?> get({required Network network});
  Future<void> set(
    ElectrumServerModel server, {
    required Network network,
  });
}

class ElectrumServerDataSourceImpl implements ElectrumServerDataSource {
  final KeyValueStorageDataSource<String> _electrumServerStorage;

  const ElectrumServerDataSourceImpl({
    required KeyValueStorageDataSource<String> electrumServerStorage,
  }) : _electrumServerStorage = electrumServerStorage;

  @override
  Future<ElectrumServerModel?> get({required Network network}) async {
    final key = '${SettingsConstants.electrumServerKeyPrefix}${network.name}';
    final value = await _electrumServerStorage.getValue(key);
    if (value == null) {
      return null;
    }
    final model = jsonDecode(value) as Map<String, dynamic>;
    return ElectrumServerModel.fromJson(model);
  }

  @override
  Future<void> set(
    ElectrumServerModel server, {
    required Network network,
  }) async {
    final key = '${SettingsConstants.electrumServerKeyPrefix}${network.name}';
    final value = jsonEncode(server.toJson());
    await _electrumServerStorage.saveValue(key: key, value: value);
  }
}
