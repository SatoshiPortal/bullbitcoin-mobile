import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart'
    show shareBullVaultRecoveryPackage;
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _VaultSource { device, server }

/// The BullVault recovery packages a backup carries.
///
/// Read-only by design: recovery from seed restores vaults on its own, so this
/// screen exists to let the user see, copy or hand on a descriptor — from the
/// backup on this device or from the one the server holds, without applying
/// anything.
class WalletVaultsScreen extends StatelessWidget {
  final WalletBackupContents? contents;

  const WalletVaultsScreen({super.key, this.contents});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = locator<BackupSettingsCubit>();
      if (contents == null) cubit.loadContents();
      return cubit;
    },
    child: _Screen(localContents: contents),
  );
}

class _Screen extends StatefulWidget {
  final WalletBackupContents? localContents;

  const _Screen({required this.localContents});

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  _VaultSource _source = _VaultSource.device;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) => SnackBarUtils.showSnackBar(
        context,
        state.failure!.toTranslated(context),
      ),
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: context.loc.walletBackupVaultsTitle,
            onBack: context.pop,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                context.loc.walletBackupVaultsDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const Gap(16),
              SegmentedButton<_VaultSource>(
                segments: [
                  ButtonSegment(
                    value: _VaultSource.device,
                    icon: const Icon(Icons.phone_android),
                    label: Text(context.loc.walletBackupVaultsSourceDevice),
                  ),
                  ButtonSegment(
                    value: _VaultSource.server,
                    icon: const Icon(Icons.cloud_outlined),
                    label: Text(context.loc.walletBackupVaultsSourceServer),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: (selection) {
                  final source = selection.single;
                  setState(() => _source = source);
                  final state = context.read<BackupSettingsCubit>().state;
                  if (source == _VaultSource.server &&
                      !state.remoteContentsLoaded) {
                    context.read<BackupSettingsCubit>().loadRemoteContents();
                  }
                },
              ),
              const Gap(16),
              BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
                builder: (context, state) => switch (_source) {
                  _VaultSource.device => _VaultList(
                    vaults: (widget.localContents ?? state.contents)?.vaults,
                    loading: state.contentsLoading,
                    emptyText: context.loc.walletBackupVaultsEmpty,
                  ),
                  _VaultSource.server when !state.remoteContentsLoaded =>
                    state.remoteContentsLoading
                        ? const _Loading()
                        : _FetchPrompt(),
                  _VaultSource.server => _VaultList(
                    vaults: state.remoteContents?.vaults ?? const [],
                    loading: state.remoteContentsLoading,
                    emptyText: state.remoteContents == null
                        ? context.loc.walletBackupVaultsServerEmpty
                        : context.loc.walletBackupVaultsEmpty,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FetchPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.loc.walletBackupVaultsServerNotFetched,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.onSurfaceVariant,
        ),
      ),
      const Gap(12),
      FilledButton.icon(
        onPressed: context.read<BackupSettingsCubit>().loadRemoteContents,
        icon: const Icon(Icons.cloud_download_outlined),
        label: Text(context.loc.walletBackupVaultsFetch),
      ),
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _VaultList extends StatelessWidget {
  final List<WalletBackupVaultSummary>? vaults;
  final bool loading;
  final String emptyText;

  const _VaultList({
    required this.vaults,
    required this.loading,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final vaults = this.vaults;
    if (vaults == null) return loading ? const _Loading() : const SizedBox();
    if (vaults.isEmpty) {
      return Text(
        emptyText,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.onSurfaceVariant,
        ),
      );
    }
    return Column(
      children: [for (final vault in vaults) _VaultCard(vault: vault)],
    );
  }
}

class _VaultCard extends StatelessWidget {
  final WalletBackupVaultSummary vault;

  const _VaultCard({required this.vault});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      context.loc.walletBackupVaultsGeneration(vault.vaultGeneration),
      _networkName(context, vault.network),
      if (vault.birthHeight case final height?)
        context.loc.walletBackupVaultsBirthHeight(height),
    ].join(' · ');
    return Card(
      child: ExpansionTile(
        // Not a PageStorageKey: the tile would share its storage bucket with
        // the descriptor's scrollable and the two types collide on restore.
        key: ValueKey(vault.walletRef),
        leading: const Icon(Icons.security),
        title: Text(vault.label ?? context.loc.walletBackupVaultsTitle),
        subtitle: Text(subtitle),
        trailing: _StatusChip(status: vault.status),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.walletBackupVaultsDescriptor,
            style: context.font.labelLarge,
          ),
          const Gap(4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              vault.descriptor,
              style: context.font.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: vault.descriptor),
                  );
                  if (context.mounted) {
                    SnackBarUtils.showSnackBar(
                      context,
                      context.loc.walletBackupVaultsDescriptorCopied,
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text(context.loc.walletBackupVaultsCopyDescriptor),
              ),
              OutlinedButton.icon(
                onPressed: () => shareBullVaultRecoveryPackage(
                  context,
                  content: vault.recoveryPackage,
                  policyId: vault.walletRef,
                ),
                icon: const Icon(Icons.ios_share),
                label: Text(context.loc.walletBackupVaultsSharePackage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'pending' => context.loc.walletBackupVaultsStatusPending,
      'activating' => context.loc.walletBackupVaultsStatusActivating,
      'active' => context.loc.walletBackupVaultsStatusActive,
      'migrating' => context.loc.walletBackupVaultsStatusMigrating,
      'cancelled' => context.loc.walletBackupVaultsStatusCancelled,
      _ => status,
    };
    final active = status == 'active';
    return Chip(
      label: Text(label),
      labelStyle: context.font.labelSmall?.copyWith(
        color: active
            ? context.appColors.onPrimary
            : context.appColors.onSurface,
      ),
      backgroundColor: active
          ? context.appColors.primary
          : context.appColors.surfaceContainerHighest,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

String _networkName(BuildContext context, Network network) => switch (network) {
  Network.bitcoinMainnet => context.loc.walletNetworkBitcoin,
  Network.bitcoinTestnet => context.loc.walletNetworkBitcoinTestnet,
  Network.liquidMainnet => context.loc.walletNetworkLiquid,
  Network.liquidTestnet => context.loc.walletNetworkLiquidTestnet,
};
