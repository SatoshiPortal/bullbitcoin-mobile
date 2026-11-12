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
    WalletSyncBusyFailure() => 'busy',
    WalletLwkStatusConflictFailure() => 'status_conflict',
    WalletUnexpectedFailure() => 'unexpected',
    WalletSelectedInputsUnavailableFailure() => 'selected_inputs_unavailable',
    WalletNoSpendableInputsFailure() => 'no_spendable_inputs',
    WalletInsufficientFundsFailure() => 'insufficient_funds',
    WalletTransactionBuildFailure() => 'transaction_build',
    WalletConsolidationRequiredFailure() => 'consolidation_required',
  };
}
