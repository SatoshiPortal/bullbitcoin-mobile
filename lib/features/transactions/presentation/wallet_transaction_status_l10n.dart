import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show BuildContext;

extension WalletTransactionStatusL10n on WalletTransactionStatus {
  String toTranslated(BuildContext context) => switch (this) {
    WalletTransactionStatus.pending =>
      context.loc.coreWalletTransactionStatusPending,
    WalletTransactionStatus.notBroadcast => context.loc.transactionNotBroadcast,
    WalletTransactionStatus.confirmed =>
      context.loc.coreWalletTransactionStatusConfirmed,
  };
}
