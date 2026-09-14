import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/backup_test_status_row.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullPasteInput, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_kit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_recovery_kit_screen.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_kit_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_qr_scanner.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

class VaultBackupScreen extends StatelessWidget {
  const VaultBackupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultBackupRecovery)),
    body: SafeArea(
      child: BlocConsumer<VaultBackupCubit, VaultBackupState>(
        listener: (context, state) {
          final message =
              state.failure?.toTranslated(context) ??
              switch ((state.verified, state.checkedSource)) {
                // Every remote source was tested, and each row says what it
                // found; one sentence cannot stand in for all of them.
                (final bool _, null) => context.loc.bullVaultBackupsChecked,
                (true, _) => context.loc.bullVaultDescriptorVerified,
                (false, VaultBackupSource.manual) =>
                  context.loc.bullVaultDescriptorMismatch,
                (false, _) => context.loc.bullVaultNoRemoteDescriptor,
                (null, _) => null,
              };
          if (message != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          final inspection = state.inspection;
          if (inspection == null) {
            return Center(
              child: state.busy
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: () => context.read<VaultBackupCubit>().load(),
                      child: Text(context.loc.retry),
                    ),
            );
          }
          final policy = inspection.record.recoveryPackage.policy;
          final cubit = context.read<VaultBackupCubit>();
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.loc.bullVaultBackupActions,
                style: context.font.titleLarge,
              ),
              const Gap(16),
              SettingsEntryItem(
                icon: Icons.qr_code,
                title: context.loc.bullVaultViewDescriptor,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        _VaultDescriptorScreen(descriptor: policy.descriptor),
                  ),
                ),
              ),
              SettingsEntryItem(
                icon: Icons.file_download_outlined,
                title: context.loc.bullVaultExportDescriptor,
                onTap: state.busy
                    ? null
                    : () => shareBullVaultRecoveryPackage(
                        context,
                        content: cubit.export(),
                        policyId: policy.id,
                      ),
              ),
              SettingsEntryItem(
                icon: Icons.verified_outlined,
                title: context.loc.bullVaultVerifyDescriptor,
                onTap: state.busy ? null : () => _verifySavedCopy(context),
              ),
              SettingsEntryItem(
                icon: Icons.cloud_upload_outlined,
                title: context.loc.vaultDestinationsEntry,
                onTap: () => context.pushNamed(
                  BullVaultFacade.backupDestinationsRouteName,
                  pathParameters: {'walletId': inspection.record.walletId},
                ),
              ),
              SettingsEntryItem(
                icon: Icons.password_outlined,
                title: context.loc.backupWordsEntry,
                onTap: () =>
                    context.pushNamed(BackupSettingsSubroute.backupWords.name),
              ),
              const Gap(32),
              for (final kind in [
                VaultRecoveryKitKind.mobile,
                VaultRecoveryKitKind.cold,
                if (policy.secondColdKey != null)
                  VaultRecoveryKitKind.secondCold,
                if (policy.inheritanceKey != null)
                  VaultRecoveryKitKind.inheritance,
              ])
                SettingsEntryItem(
                  icon: Icons.description_outlined,
                  title: VaultRecoveryKitScreen.title(context, kind),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => locator<VaultRecoveryKitCubit>(),
                        child: VaultRecoveryKitScreen(
                          policy: policy,
                          walletId: inspection.record.walletId,
                          kind: kind,
                        ),
                      ),
                    ),
                  ),
                ),
              const Gap(32),
              Text(
                context.loc.vaultDestinationsTitle,
                style: context.font.titleLarge,
              ),
              const Gap(16),
              for (final destination in VaultBackupDestination.values) ...[
                Row(
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
                      _publicationStatus(context, state, destination),
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Gap(12),
              ],
              if (state.hasOutstandingPublication)
                BullButton.big(
                  label: context.loc.retry,
                  disabled: state.busy,
                  outlined: true,
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                  onPressed: cubit.retryPublications,
                ),
              const Gap(32),
              Text(
                context.loc.bullVaultLastTestedDate,
                style: context.font.titleLarge,
              ),
              if (inspection.historyFailure != null) ...[
                const Gap(16),
                Text(inspection.historyFailure!.toTranslated(context)),
              ],
              const Gap(24),
              for (final source in VaultBackupSource.values) ...[
                if (source == VaultBackupSource.bitcoin)
                  // On-chain publication is deferred: neutral and never tested.
                  BackupTestStatusRow.unavailable(
                    label: context.loc.bullVaultTestBitcoin,
                  )
                else
                  BackupTestStatusRow(
                    latestAttempt: switch (state.latest[source]) {
                      null || VaultBackupCheckStatus.success => null,
                      VaultBackupCheckStatus.failed =>
                        context.loc.bullVaultCheckLatestFailed,
                      VaultBackupCheckStatus.unavailable =>
                        context.loc.bullVaultCheckLatestUnavailable,
                      VaultBackupCheckStatus.incomplete =>
                        context.loc.bullVaultCheckLatestIncomplete,
                    },
                    label: switch (source) {
                      VaultBackupSource.manual =>
                        context.loc.bullVaultTestManual,
                      VaultBackupSource.metadata =>
                        context.loc.bullVaultTestMetadata,
                      VaultBackupSource.bip138 =>
                        context.loc.bullVaultTestBip138,
                      VaultBackupSource.nostr => context.loc.bullVaultTestNostr,
                      VaultBackupSource.bitcoin =>
                        context.loc.bullVaultTestBitcoin,
                    },
                    testedAt: inspection.testedAt[source],
                  ),
                const Gap(24),
              ],
              BullButton.big(
                onPressed: cubit.checkAgain,
                disabled: state.busy,
                loading: state.busy,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
                label: state.busy
                    ? context.loc.bullVaultChecking
                    : context.loc.bullVaultCheckAgain,
              ),
            ],
          );
        },
      ),
    ),
  );

  String _publicationStatus(
    BuildContext context,
    VaultBackupState state,
    VaultBackupDestination destination,
  ) {
    final row = state.publications
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

  Future<void> _verifySavedCopy(BuildContext context) async {
    final cubit = context.read<VaultBackupCubit>();
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _VerifyDescriptorScreen(onImport: cubit.importFile),
      ),
    );
    if (result != null && !cubit.isClosed) await cubit.verifyManual(result);
  }
}

final class _VaultDescriptorScreen extends StatelessWidget {
  final String descriptor;

  const _VaultDescriptorScreen({required this.descriptor});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultViewDescriptor)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AspectRatio(aspectRatio: 1, child: QrDisplayWidget(data: descriptor)),
          const Gap(24),
          CopyInput(text: descriptor, maxLines: null),
        ],
      ),
    ),
  );
}

class _VerifyDescriptorScreen extends StatefulWidget {
  final Future<void> Function() onImport;
  const _VerifyDescriptorScreen({required this.onImport});
  @override
  State<_VerifyDescriptorScreen> createState() =>
      _VerifyDescriptorScreenState();
}

class _VerifyDescriptorScreenState extends State<_VerifyDescriptorScreen> {
  String _text = '';
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultVerifyDescriptor)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.loc.bullVaultDescriptorImportHint),
          const Gap(24),
          BullPasteInput(
            text: _text,
            hint: context.loc.bullVaultDescriptorHint,
            onChanged: (value) => setState(() => _text = value),
            minLines: 4,
            maxLines: 10,
            enabled: !_busy,
            onScan: () async {
              final scanned = await pushVaultQrScanner(
                context,
                title: context.loc.bullVaultScanDescriptor,
              );
              if (mounted && scanned != null) setState(() => _text = scanned);
            },
          ),
          const Gap(16),
          BullButton.big(
            label: context.loc.bullVaultVerifyDescriptor,
            disabled: _busy,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
            onPressed: () {
              if (_text.trim().isNotEmpty) Navigator.of(context).pop(_text);
            },
          ),
          const Gap(16),
          BullButton.big(
            label: context.loc.bullVaultImportFile,
            disabled: _busy,
            outlined: true,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
            onPressed: () async {
              setState(() => _busy = true);
              await widget.onImport();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  );
}
