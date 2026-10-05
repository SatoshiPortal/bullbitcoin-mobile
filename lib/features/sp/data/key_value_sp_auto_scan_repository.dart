import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';

class KeyValueSpAutoScanRepository implements SpAutoScanRepository {
  static const String _storageKey = 'sp_auto_scan_enabled';

  final KeyValueStorageDatasource<String> _storage;

  // Enabled until storage or the user says otherwise, so a read before warmUp
  // never has to guess.
  bool _isEnabled = true;

  KeyValueSpAutoScanRepository({required this._storage});

  @override
  bool get isEnabledNow => _isEnabled;

  @override
  Future<void> warmUp() async {
    _isEnabled = await _read() ?? true;
  }

  @override
  Future<void> save({required bool isEnabled}) async {
    _isEnabled = isEnabled;
    await _storage.saveValue(key: _storageKey, value: '$isEnabled');
  }

  Future<bool?> _read() async {
    final stored = await _storage.getValue(_storageKey);
    if (stored == null || stored.isEmpty) return null;
    return stored == 'true';
  }
}
