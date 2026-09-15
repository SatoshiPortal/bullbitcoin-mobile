import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_destinations_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullCheckbox, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Where this vault's descriptor is kept besides the copy the person saved.
///
/// Nothing starts unchecked-to-checked on its own and nothing is sent before
/// Continue: publication is a choice, and the choice is per vault. Continue
/// works with no selection at all, because every one of these is optional and
/// none of them can hold up the rest of setup.
class VaultDestinationsScreen extends StatelessWidget {
  const VaultDestinationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.vaultDestinationsTitle)),
    body: SafeArea(
      child: BlocBuilder<VaultDestinationsCubit, VaultDestinationsState>(
        builder: (context, state) {
          final cubit = context.read<VaultDestinationsCubit>();
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.loc.vaultDestinationsDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const Gap(24),
              if (state.published)
                ..._results(context, state)
              else
                ..._choices(context, state, cubit),
              const Gap(24),
              Text(
                context.loc.vaultDestinationsNeverBlocks,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const Gap(16),
              // The vault names the wallet it was created on, and everything
              // this screen publishes is sealed to that wallet's words. A
              // vault this phone kept no Mobile seed for names none, and this
              // phone's own words open nothing of its.
              if (state.originFingerprint case final origin?)
                SettingsEntryItem(
                  icon: Icons.password_outlined,
                  title: context.loc.backupWordsEntry,
                  onTap: () => context.pushNamed(
                    BackupSettingsSubroute.backupWords.name,
                    extra: origin,
                  ),
                ),
              SettingsEntryItem(
                icon: Icons.cloud_outlined,
                title: context.loc.dataBackupSettingsTitle,
                onTap: () =>
                    context.pushNamed(SettingsRoute.dataBackupSettings.name),
              ),
              Text(
                state.dataBackup?.enabled ?? false
                    ? context.loc.vaultDestinationsDataBackupOn
                    : context.loc.vaultDestinationsDataBackupOff,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const Gap(4),
              Text(
                context.loc.vaultDestinationsDataBackupNote,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              if (state.failure case final failure?) ...[
                const Gap(16),
                Text(
                  failure.toTranslated(context),
                  style: context.font.bodyMedium,
                ),
              ],
              const Gap(24),
              BullButton.big(
                label: context.loc.continueButton,
                disabled: state.busy,
                loading: state.busy,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
                onPressed: () async {
                  if (state.published || !state.anyEnabled) {
                    await Navigator.of(context).maybePop();
                    return;
                  }
                  await cubit.publish();
                },
              ),
              if (state.published && state.anyOutstanding) ...[
                const Gap(12),
                BullButton.big(
                  label: context.loc.retry,
                  disabled: state.busy,
                  outlined: true,
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                  onPressed: cubit.retry,
                ),
              ],
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _choices(
    BuildContext context,
    VaultDestinationsState state,
    VaultDestinationsCubit cubit,
  ) => [
    _Choice(
      title: context.loc.vaultDestinationsServer,
      description: context.loc.vaultDestinationsServerDescription,
      tag: context.loc.vaultDestinationsRecommended,
      checked: state.enabled(VaultBackupDestination.server),
      onChanged: state.busy
          ? null
          : (value) => cubit.setEnabled(VaultBackupDestination.server, value),
    ),
    _Choice(
      title: context.loc.vaultDestinationsNostr,
      description: context.loc.vaultDestinationsNostrDescription,
      checked: state.enabled(VaultBackupDestination.nostr),
      onChanged: state.busy
          ? null
          : (value) => cubit.setEnabled(VaultBackupDestination.nostr, value),
    ),
    // On-chain publication is deferred: it cannot be chosen and never runs.
    _Choice(
      title: context.loc.bullVaultTestBitcoin,
      description: context.loc.vaultDestinationsBitcoinDescription,
      tag: context.loc.backupSettingsComingSoon,
      checked: false,
      onChanged: null,
    ),
  ];

  List<Widget> _results(BuildContext context, VaultDestinationsState state) => [
    for (final destination in VaultBackupDestination.values)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(switch (destination) {
                VaultBackupDestination.server =>
                  context.loc.vaultDestinationsServer,
                VaultBackupDestination.nostr =>
                  context.loc.vaultDestinationsNostr,
              }, style: context.font.bodyMedium),
            ),
            const Gap(12),
            Text(
              _outcome(context, state, destination),
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    Row(
      children: [
        Expanded(
          child: Text(
            context.loc.bullVaultTestBitcoin,
            style: context.font.bodyMedium,
          ),
        ),
        const Gap(12),
        Text(
          context.loc.backupSettingsComingSoon,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  ];

  String _outcome(
    BuildContext context,
    VaultDestinationsState state,
    VaultBackupDestination destination,
  ) {
    final row = state.rows
        .where((row) => row.destination == destination)
        .firstOrNull;
    if (row == null || !row.enabled) {
      return context.loc.vaultDestinationsNotSelected;
    }
    return switch (row.state) {
      VaultPublicationState.verified => context.loc.vaultDestinationsVerified,
      VaultPublicationState.sent => context.loc.vaultDestinationsSent,
      VaultPublicationState.failed => context.loc.vaultDestinationsFailed,
      VaultPublicationState.idle ||
      VaultPublicationState.pending => context.loc.vaultDestinationsPending,
    };
  }
}

class _Choice extends StatelessWidget {
  final String title;
  final String description;
  final String? tag;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  const _Choice({
    required this.title,
    required this.description,
    required this.checked,
    required this.onChanged,
    this.tag,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullCheckbox(
          checked: checked,
          onChanged: onChanged,
          disabled: onChanged == null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: context.font.bodyLarge)),
                    if (tag != null) ...[
                      const Gap(8),
                      Text(
                        tag!,
                        style: context.font.bodySmall?.copyWith(
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const Gap(4),
                Text(
                  description,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
