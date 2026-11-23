import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;

import '../domain/entities/wallet_transaction.dart';

extension WalletTransactionStatusL10n on WalletTransactionStatus {
  String displayName(BuildContext context) => switch (this) {
    WalletTransactionStatus.pending =>
      context.loc.coreWalletTransactionStatusPending,
    WalletTransactionStatus.confirmed =>
      context.loc.coreWalletTransactionStatusConfirmed,
  };
}
