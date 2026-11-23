import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' show SyncReason;
import 'package:primitives/legacy_exceptions.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

class SyncWalletUsecase {
  final WalletRepository _wallet;

  SyncWalletUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<void> execute(
    Wallet wallet, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
  }) async {
    try {
      await _wallet.sync(
        wallet,
        discover: discover,
        reason: reason,
        allowInitialScan: allowInitialScan,
      );
    } on WalletSnapshotException {
      rethrow;
    } catch (e) {
      throw SyncWalletException('$e');
    }
  }
}

class SyncWalletException extends BullException {
  SyncWalletException(super.message);
}
