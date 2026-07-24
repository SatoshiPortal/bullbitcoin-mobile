import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// Adapts the existing Electrum sync path on [WalletRepository] to the
/// [WalletSyncRepository] contract.
///
/// This class changes no Electrum behaviour: it calls the same
/// [WalletRepository.getWallet]/[WalletRepository.sync] that every other
/// caller uses, so server selection/fallback and the per-wallet
/// single-flight guarantee (owned by the underlying BDK/LWK datasources)
/// are unchanged. It only translates the outcome into [Result] and emits
/// [WalletSyncProgress] around the call.
///
/// Electrum's full scan has no mid-flight cancellation and no determinate
/// progress, so [cancelSync] is a documented no-op and [watchProgress] only
/// ever emits [WalletSyncStarted] followed by [WalletSyncCompleted] for a
/// given wallet — never [WalletSyncScanning] or [WalletSyncWarningRaised].
class ElectrumWalletSyncRepository implements WalletSyncRepository {
  final WalletRepository _walletRepository;
  final _progressController = StreamController<WalletSyncProgress>.broadcast();

  ElectrumWalletSyncRepository({required this._walletRepository});

  @override
  Future<Result<void, WalletSyncFailure>> startSync({
    required String walletId,
  }) async {
    final wallet = await _walletRepository.getWallet(walletId);
    if (wallet == null) {
      return const Err(WalletSyncWalletNotFoundFailure());
    }

    _progressController.add(
      WalletSyncStarted(walletId, BitcoinSyncBackend.electrum),
    );
    try {
      await _walletRepository.sync(wallet);
      _progressController.add(WalletSyncCompleted(walletId));
      return const Ok(null);
    } on ElectrumFallbackException catch (e) {
      _progressController.add(
        WalletSyncFailed(walletId, WalletSyncFailureCategory.electrum),
      );
      return Err(WalletSyncElectrumFailure(e.message));
    } catch (e) {
      _progressController.add(
        WalletSyncFailed(walletId, WalletSyncFailureCategory.electrum),
      );
      return Err(WalletSyncUnexpectedFailure('$e'));
    }
  }

  @override
  Stream<WalletSyncProgress> watchProgress() => _progressController.stream;

  @override
  Future<void> cancelSync({required String walletId}) async {
    // Electrum's full scan cannot be interrupted mid-flight. Any in-flight
    // attempt for this wallet completes naturally and its outcome is
    // reported by the Result the corresponding startSync call resolves
    // with — nothing to do here today.
  }
}
