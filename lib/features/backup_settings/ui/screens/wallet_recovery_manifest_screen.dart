import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            if (wallet.label != null)
              Text(
                _walletType(context, wallet.provenance),
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
            Text(
              _networkName(context, wallet.network),
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            _Detail(
              label: context.loc.walletBackupManifestKeys,
              value: _keyLocation(context, wallet),
            ),
            if (wallet.derivationPath case final path?)
              _Detail(
                label: context.loc.walletBackupManifestSourcePath,
                value: path,
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
            if (wallet.descriptor case final descriptor?) ...[
              const Gap(8),
              _DescriptorDetail(
                label: context.loc.walletDetailsDescriptorLabel,
                descriptor: descriptor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DescriptorDetail extends StatelessWidget {
  final String label;
  final String descriptor;

  const _DescriptorDetail({required this.label, required this.descriptor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              Text(_shortDescriptor(descriptor), maxLines: 1),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _viewDescriptor(context, label, descriptor),
          child: Text(context.loc.walletBackupManifestView),
        ),
      ],
    ),
  );
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
      WalletProvenance.defaultSeedPassphrase =>
        context.loc.walletBackupManifestPassphraseWallet,
      WalletProvenance.bip85 => context.loc.walletBackupManifestBip85,
      WalletProvenance.importedMnemonic =>
        context.loc.walletBackupManifestImportedMnemonic,
      WalletProvenance.watchOnly => context.loc.walletBackupManifestWatchOnly,
      WalletProvenance.externalSigner =>
        context.loc.walletBackupManifestExternalSigner,
    };

String _networkName(BuildContext context, Network network) => switch (network) {
  Network.bitcoinMainnet => context.loc.walletNetworkBitcoin,
  Network.bitcoinTestnet => context.loc.walletNetworkBitcoinTestnet,
  Network.liquidMainnet => context.loc.walletNetworkLiquid,
  Network.liquidTestnet => context.loc.walletNetworkLiquidTestnet,
};

String _keyLocation(BuildContext context, WalletBackupWalletSummary wallet) {
  if (wallet.provenance == WalletProvenance.defaultSeedPassphrase) {
    return context.loc.walletBackupManifestKeysPassphrase;
  }
  if (wallet.keysOnDevice) return context.loc.walletBackupManifestKeysOnDevice;
  return switch (wallet.provenance) {
    WalletProvenance.externalSigner =>
      context.loc.walletBackupManifestKeysExternal,
    WalletProvenance.watchOnly => context.loc.walletBackupManifestKeysAbsent,
    _ => context.loc.walletBackupManifestKeysRequired,
  };
}

String? _passphrase(BuildContext context, WalletBackupWalletSummary wallet) =>
    switch (wallet.provenance) {
      WalletProvenance.watchOnly || WalletProvenance.externalSigner => null,
      _ => switch (wallet.seedPassphraseUsed) {
        true => context.loc.walletBackupManifestPassphraseUsed,
        false => context.loc.walletBackupManifestPassphraseNotUsed,
        null => context.loc.walletBackupManifestPassphraseUnknown,
      },
    };

String _shortDescriptor(String value) => value.length <= 40
    ? value
    : '${value.substring(0, 24)}…${value.substring(value.length - 12)}';

Future<void> _viewDescriptor(
  BuildContext context,
  String label,
  String descriptor,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(label),
    content: SingleChildScrollView(child: SelectableText(descriptor)),
    actions: [
      TextButton(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: descriptor));
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
        child: Text(dialogContext.loc.walletBackupManifestCopy),
      ),
    ],
  ),
);
