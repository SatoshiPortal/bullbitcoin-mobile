import 'dart:async';

import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Turns automatic scanning on or off. The repository owns the cached value the
/// sync path and the UI read, so this only writes.
class SetSpAutoScanUsecase {
  final SpAutoScanRepository _repository;

  final SyncSpWalletUsecase? _syncWallet;

  SetSpAutoScanUsecase({required this._repository, this._syncWallet});

  Future<Result<void, SpFailure>> execute({required bool isEnabled}) async {
    try {
      await _repository.save(isEnabled: isEnabled);
    } on Exception catch (_) {
      return const Err(
        SpUnexpected('SP automatic scanning preference save failed'),
      );
    }
    final sync = _syncWallet;
    if (isEnabled && sync != null) unawaited(_syncAfterEnabling(sync));
    return const Ok(null);
  }

  Future<void> _syncAfterEnabling(SyncSpWalletUsecase sync) async {
    if (await sync.execute() case Err(:final failure)) {
      log.warning(
        'SP sync after enabling automatic scanning: ${failure.logMessage}',
      );
    }
  }
}
