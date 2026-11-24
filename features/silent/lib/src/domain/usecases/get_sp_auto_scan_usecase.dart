import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/repositories/sp_auto_scan_repository.dart';

/// Whether the wallet may resume scanning on its own.
///
/// [execute] is the synchronous read the UI and the in-flight checks use.
/// [read] is for the sync tick, which can await: it loads the persisted choice
/// first, so the first tick after a cold start cannot act on the optimistic
/// default before the keystore read finished.
class GetSpAutoScanUsecase {
  final SpAutoScanRepository _repository;

  GetSpAutoScanUsecase({required this._repository});

  bool execute() => _repository.isEnabledNow;

  /// The persisted choice, or false when it cannot be read: an automatic scan
  /// is never worth guessing about.
  Future<bool> read() async {
    try {
      return switch (await _repository.warmUp()) {
        Ok() => execute(),
        Err() => false,
      };
    } on Exception catch (_) {
      return false;
    }
  }
}
