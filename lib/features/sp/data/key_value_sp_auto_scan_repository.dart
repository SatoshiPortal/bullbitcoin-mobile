import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';

class KeyValueSpAutoScanRepository implements SpAutoScanRepository {
  final SilentPaymentKeychain _storage;

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
    final result = await _storage.writeAutoScan('$isEnabled');
    if (result case Err(:final failure)) throw Exception(failure.logMessage);
  }

  Future<bool?> _read() async {
    final result = await _storage.readAutoScan();
    if (result case Err(:final failure)) throw Exception(failure.logMessage);
    final stored = (result as Ok<String?, SecretFailure>).value;
    if (stored == null || stored.isEmpty) return null;
    return stored == 'true';
  }
}
