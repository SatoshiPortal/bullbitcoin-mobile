import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

extension WalletFailureLogCode on WalletFailure {
  String get logCode => switch (this) {
    WalletTransactionLookupFailure() => 'transaction_lookup',
    WalletStorageFailure() => 'storage',
    WalletNotFoundFailure() => 'not_found',
    NoWalletsFoundFailure() => 'no_wallets',
    WalletCannotDeleteDefaultFailure() => 'default_wallet',
    WalletCannotDeleteWithOngoingSwapsFailure() => 'ongoing_swaps',
    WalletSyncFailure() => 'sync',
    WalletLwkStatusConflictFailure() => 'status_conflict',
    WalletUnexpectedFailure() => 'unexpected',
  };
}
