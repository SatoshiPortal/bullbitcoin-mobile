import 'package:flutter/widgets.dart';

import '../generated/l10n/backups_localizations.dart';
import 'domain/backup_wallet.dart';

extension BackupsL10n on BuildContext {
  BackupsLocalizations get loc => BackupsLocalizations.of(this);

  String backupWalletName(BackupWallet wallet) => wallet.isDefault
      ? loc.globalDefaultBitcoinWalletLabel
      : wallet.label ?? loc.walletDetailsUnnamedWalletFallback;
}
