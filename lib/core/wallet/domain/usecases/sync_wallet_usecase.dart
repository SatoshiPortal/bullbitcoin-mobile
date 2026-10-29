import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class SyncWalletUsecase {
  final WalletRepository _wallet;

  SyncWalletUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  /// [discoverHistory] also scans addresses the wallet has not revealed, up
  /// to the stop gap; only explicit user refreshes ask for it.
  Future<void> execute(
    Wallet wallet, {
    bool discoverHistory = false,
    bool allowInitialScan = true,
  }) async {
    try {
      await _wallet.sync(
        wallet,
        discoverHistory: discoverHistory,
        allowInitialScan: allowInitialScan,
      );
    } on BitcoinSyncOperationException {
      rethrow;
    } catch (e) {
      throw SyncWalletException('$e');
    }
  }
}

class SyncWalletException extends BullException {
  SyncWalletException(super.message);
}
