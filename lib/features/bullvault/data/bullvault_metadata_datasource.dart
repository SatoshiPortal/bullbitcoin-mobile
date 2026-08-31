import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_model.dart';

final class BullVaultMetadataDatasource {
  static const _generationReservationPrefix =
      'bullvault_generation_reservations_';
  static const _recordPrefix = 'bullvault_record_';

  final KeyValueStorageDatasource<String> _storage;

  const BullVaultMetadataDatasource(this._storage);

  Future<void> save(BullVaultRecordModel model) => _storage.saveValue(
    key: '$_recordPrefix${model.walletId}',
    value: jsonEncode(model.toJson()),
  );

  Future<void> delete(String walletId) =>
      _storage.deleteValue('$_recordPrefix$walletId');

  Future<BullVaultRecordModel?> load(String walletId) async {
    final value = await _storage.getValue('$_recordPrefix$walletId');
    if (value == null) return null;
    return BullVaultRecordModel.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  Future<List<BullVaultRecordModel>> loadLineage(String lineageId) async {
    final records = await loadAll();
    return records.where((record) => record.lineageId == lineageId).toList()
      ..sort(
        (first, second) =>
            first.vaultGeneration.compareTo(second.vaultGeneration),
      );
  }

  Future<List<BullVaultRecordModel>> loadAll() async {
    final values = await _storage.getAll();
    return [
      for (final entry in values.entries)
        if (entry.key.startsWith(_recordPrefix))
          BullVaultRecordModel.fromJson(
            jsonDecode(entry.value) as Map<String, dynamic>,
          ),
    ];
  }

  Future<Set<int>> loadGenerationReservations(String lineageId) async {
    final value = await _storage.getValue(
      '$_generationReservationPrefix$lineageId',
    );
    if (value == null) return {};
    final decoded = jsonDecode(value);
    if (decoded is! List<dynamic> || decoded.any((value) => value is! int)) {
      throw const FormatException('Invalid BullVault generation reservations');
    }
    return decoded.cast<int>().toSet();
  }

  Future<void> saveGenerationReservations(
    String lineageId,
    Set<int> generations,
  ) => _storage.saveValue(
    key: '$_generationReservationPrefix$lineageId',
    value: jsonEncode(generations.toList()..sort()),
  );
}
