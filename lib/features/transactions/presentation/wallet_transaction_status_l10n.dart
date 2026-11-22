import 'package:bb_mobile/core/utils/build_context_x.dart';
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
