import 'package:bb_mobile/localization/app_localizations_context.dart';
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
