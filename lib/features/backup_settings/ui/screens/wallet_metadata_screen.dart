import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WalletMetadataScreen extends StatelessWidget {
  final List<WalletBackupMetadataSummary> metadata;

  const WalletMetadataScreen({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.walletBackupMetadataTitle,
          onBack: context.pop,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              context.loc.walletBackupMetadataDescription,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(16),
            for (final section in metadata)
              Card(
                child: ListTile(
                  leading: Icon(_icon(section.recordType)),
                  title: Text(_title(context, section.recordType)),
                  trailing: Text(section.recordCount.toString()),
                ),
              ),
            const Gap(16),
            Text(
              context.loc.walletBackupMetadataExcluded,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _title(BuildContext context, String type) => switch (type) {
  'labels.bip329' => context.loc.walletBackupMetadataLabels,
  'wallet.preferences' => context.loc.walletBackupMetadataPreferences,
  'wallet.utxo_freeze' => context.loc.walletBackupMetadataFrozenCoins,
  _ => type,
};

IconData _icon(String type) => switch (type) {
  'labels.bip329' => Icons.sell_outlined,
  'wallet.preferences' => Icons.tune,
  'wallet.utxo_freeze' => Icons.ac_unit,
  _ => Icons.description_outlined,
};
