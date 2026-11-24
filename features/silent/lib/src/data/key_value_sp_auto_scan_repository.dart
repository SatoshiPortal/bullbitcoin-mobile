import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/repositories/sp_auto_scan_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';

class KeyValueSpAutoScanRepository implements SpAutoScanRepository {
  final SilentPaymentKeychain _storage;

  // Enabled until storage or the user says otherwise, so a read before warmUp
  // never has to guess.
  bool _isEnabled = true;
  int _writeRevision = 0;
  Future<void> _pendingWrite = Future.value();

  KeyValueSpAutoScanRepository({required this._storage});

  @override
  bool get isEnabledNow => _isEnabled;

  @override
  Future<Result<void, SilentFailure>> warmUp() async {
    final revision = _writeRevision;
    await _pendingWrite;
    if (revision != _writeRevision) return const Ok(null);
    switch (await _storage.readAutoScan()) {
      case Err():
        return const Err(SilentUnexpected('Silent auto-scan read failed'));
      case Ok(value: final stored):
        if (revision == _writeRevision) {
          _isEnabled = stored == null || stored.isEmpty || stored == 'true';
        }
        return const Ok(null);
    }
  }

  @override
  Future<Result<void, SilentFailure>> save({required bool isEnabled}) {
    _writeRevision++;
    _isEnabled = isEnabled;
    final write = _pendingWrite.then((_) async {
      return (await _storage.writeAutoScan(
        '$isEnabled',
      )).mapErr((_) => const SilentUnexpected('Silent auto-scan write failed'));
    });
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }
}
