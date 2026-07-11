import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';

/// Reads a fresh SP wallet snapshot. When a session is live it returns that
/// session's current snapshot; when none exists `EnsureSpSession` establishes
/// one via `createFromMnemonic`. It never disposes a live session: the scanner
/// updates the live stores in place, so the snapshot is already current, and
/// tearing the session down here would kill a running background scan.
class RefreshSpWalletUsecase {
  final SpAccountRepository _repository;
  final GetSpWalletUsecase _getSpWalletUsecase;

  RefreshSpWalletUsecase({
    required this._repository,
    required this._getSpWalletUsecase,
  });

  /// Whether a scan is running (tracked in Dart, no FFI).
  bool get isScanning => _repository.isScanningCached;

  Future<SpWallet?> execute() => _getSpWalletUsecase.execute();
}
