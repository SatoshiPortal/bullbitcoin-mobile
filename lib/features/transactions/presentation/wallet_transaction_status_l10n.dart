import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/domain/entities/wallet_transaction.dart';
import 'package:flutter/widgets.dart';

extension WalletTransactionStatusL10n on WalletTransactionStatus {
  String displayName(BuildContext context) {
    switch (this) {
      case WalletTransactionStatus.pending:
        return context.loc.coreWalletTransactionStatusPending;
      case WalletTransactionStatus.confirmed:
        return context.loc.coreWalletTransactionStatusConfirmed;
    }
  }
}
