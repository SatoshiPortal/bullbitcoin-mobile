import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WalletRecoveryManifestScreen extends StatelessWidget {
  final List<WalletBackupWalletSummary> wallets;

  const WalletRecoveryManifestScreen({super.key, required this.wallets});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.walletBackupManifestTitle,
          onBack: context.pop,
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: wallets.length + 1,
          separatorBuilder: (_, _) => const Gap(12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                context.loc.walletBackupManifestDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              );
            }
            return _WalletCard(wallet: wallets[index - 1]);
          },
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final WalletBackupWalletSummary wallet;

  const _WalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final birthday = wallet.birthday?.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wallet.label ?? _walletType(context, wallet.provenance),
              style: context.font.titleSmall,
            ),
            const Gap(4),
            Text(
              wallet.network.name,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            _Detail(
              label: context.loc.walletBackupManifestRecovery,
              value: _recovery(context, wallet.provenance),
            ),
            _Detail(
              label: context.loc.walletBackupManifestDefinition,
              value: wallet.publicDefinitionIncluded
                  ? context.loc.walletBackupManifestDefinitionIncluded
                  : context.loc.walletBackupManifestLiquidDefinitionExcluded,
            ),
            if (wallet.signerDevice case final signer?)
              _Detail(
                label: context.loc.walletBackupManifestSigner,
                value: signer.displayName,
              ),
            if (_passphrase(context, wallet) case final passphrase?)
              _Detail(
                label: context.loc.walletBackupManifestPassphrase,
                value: passphrase,
              ),
            if (birthday != null)
              _Detail(
                label: context.loc.walletBackupManifestBirthday,
                value: MaterialLocalizations.of(
                  context,
                ).formatMediumDate(birthday),
              ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;

  const _Detail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ),
          const Gap(16),
          Expanded(flex: 2, child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

String _walletType(BuildContext context, WalletProvenance provenance) =>
    switch (provenance) {
      WalletProvenance.defaultSeed => context.loc.walletBackupManifestDefault,
      WalletProvenance.bip85 => context.loc.walletBackupManifestBip85,
      WalletProvenance.importedMnemonic =>
        context.loc.walletBackupManifestImportedMnemonic,
      WalletProvenance.watchOnly => context.loc.walletBackupManifestWatchOnly,
      WalletProvenance.externalSigner =>
        context.loc.walletBackupManifestExternalSigner,
    };

String _recovery(BuildContext context, WalletProvenance provenance) =>
    switch (provenance) {
      WalletProvenance.defaultSeed =>
        context.loc.walletBackupManifestRecoveryMainSeed,
      WalletProvenance.bip85 => context.loc.walletBackupManifestRecoveryBip85,
      WalletProvenance.importedMnemonic =>
        context.loc.walletBackupManifestRecoveryImportedMnemonic,
      WalletProvenance.watchOnly =>
        context.loc.walletBackupManifestRecoveryWatchOnly,
      WalletProvenance.externalSigner =>
        context.loc.walletBackupManifestRecoveryExternalSigner,
    };

String? _passphrase(BuildContext context, WalletBackupWalletSummary wallet) =>
    switch (wallet.provenance) {
      WalletProvenance.watchOnly || WalletProvenance.externalSigner => null,
      _ => switch (wallet.seedPassphraseUsed) {
        true => context.loc.walletBackupManifestPassphraseUsed,
        false => context.loc.walletBackupManifestPassphraseNotUsed,
        null => context.loc.walletBackupManifestPassphraseUnknown,
      },
    };
