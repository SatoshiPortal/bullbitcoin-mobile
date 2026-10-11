import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullSpacing;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';

class DataBackupRecoveryResult extends StatelessWidget {
  final WalletBackupRecovery result;
  const DataBackupRecoveryResult({super.key, required this.result});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: BullSpacing.md,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        result.complete
            ? context.loc.dataBackupRecoveryComplete
            : context.loc.dataBackupRecoveryIncomplete,
        style: context.font.titleMedium,
      ),
      for (final entry in result.wallets.walletReferences.entries)
        ListTile(title: Text(entry.key), subtitle: Text(entry.value)),
      for (final reference in result.wallets.failedReferences)
        ListTile(
          title: Text(reference),
          subtitle: Text(context.loc.dataBackupWalletNotRecovered),
        ),
    ],
  );
}
