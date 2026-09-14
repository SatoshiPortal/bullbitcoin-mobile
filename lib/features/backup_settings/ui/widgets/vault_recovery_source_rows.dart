import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/backup_test_status_row.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// Where a recovery looked, and what each place said.
///
/// The three sources are independent rows on purpose: one that cannot be
/// reached is not the same as one that answered and held nothing, and the
/// Bitcoin row is a fixed Coming soon that never turns into a pending request.
class VaultRecoverySourceRows extends StatelessWidget {
  final Map<VaultRecoverySource, VaultRecoverySourceStatus> sources;

  const VaultRecoverySourceRows({super.key, required this.sources});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final source in VaultRecoverySource.values) ...[
        BackupTestStatusRow.state(
          label: switch (source) {
            VaultRecoverySource.dataBackup => context.loc.bullVaultTestMetadata,
            VaultRecoverySource.nostr => context.loc.bullVaultTestNostr,
            VaultRecoverySource.bitcoin => context.loc.bullVaultTestBitcoin,
          },
          state: _status(context, source),
        ),
        const Gap(12),
      ],
    ],
  );

  String _status(BuildContext context, VaultRecoverySource source) {
    // On-chain publication is deferred: neutral, never pending, never failed.
    if (source == VaultRecoverySource.bitcoin) {
      return context.loc.backupSettingsComingSoon;
    }
    return switch (sources[source] ?? VaultRecoverySourceStatus.idle) {
      VaultRecoverySourceStatus.idle => '',
      VaultRecoverySourceStatus.checking => context.loc.bullVaultChecking,
      VaultRecoverySourceStatus.found => context.loc.vaultRecoveryImported,
      VaultRecoverySourceStatus.none => context.loc.vaultRecoveryNone,
      VaultRecoverySourceStatus.unavailable =>
        context.loc.vaultRecoveryUnavailableSource,
      VaultRecoverySourceStatus.incomplete =>
        context.loc.vaultRecoveryIncomplete,
    };
  }
}
