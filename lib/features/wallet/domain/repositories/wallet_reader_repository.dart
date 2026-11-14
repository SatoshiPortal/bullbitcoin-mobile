import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Read-only access to one known wallet; never starts a synchronization.
abstract interface class WalletReaderRepository {
  @useResult
  Future<Result<Wallet, WalletFailure>> getWallet(String walletId);
}
