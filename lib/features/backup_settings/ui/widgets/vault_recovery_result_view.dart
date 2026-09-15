import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, Gap;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// What one recovery attempt did, candidate by candidate.
///
/// A lookup hands back records nobody vouched for, so "this key does not open
/// that backup" is the ordinary outcome and sits beside the recovered vaults
/// rather than replacing them. Every manual entry and the landing itself show
/// the same thing, which is why this is a widget and not four copies.
///
/// New widget: `lib/core/widgets/`, `packages/bull_ui/` and the feature's own
/// `ui/` hold nothing that renders per-candidate recovery outcomes.
class VaultRecoveryResultView extends StatelessWidget {
  final List<VaultRecoveryOutcome> outcomes;

  const VaultRecoveryResultView({super.key, required this.outcomes});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.loc.vaultRecoveryResultTitle,
        style: context.font.titleMedium,
      ),
      const Gap(8),
      if (outcomes.isEmpty)
        Text(
          context.loc.vaultRecoveryNothingYet,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurfaceVariant,
          ),
        )
      else
        for (final outcome in outcomes) ...[
          _Outcome(outcome: outcome),
          const Gap(8),
        ],
      const Gap(8),
      Text(
        context.loc.vaultRecoveryNoSpendDisclosure,
        style: context.font.bodySmall?.copyWith(
          color: context.appColors.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _Outcome extends StatelessWidget {
  final VaultRecoveryOutcome outcome;

  const _Outcome({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final walletId = outcome.walletId;
    return BullBorderedTile(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(switch (outcome.status) {
            VaultRecoveryStatus.imported => context.loc.vaultRecoveryImported,
            VaultRecoveryStatus.alreadyPresent =>
              context.loc.vaultRecoveryAlreadyPresent,
            VaultRecoveryStatus.undecryptable =>
              context.loc.vaultRecoveryUndecryptable,
            VaultRecoveryStatus.unsupported =>
              context.loc.vaultRecoveryUnsupported,
          }, style: context.font.bodyLarge),
          if (walletId != null) ...[
            const Gap(8),
            Text(
              outcome.signingKeyOnThisDevice
                  ? context.loc.vaultRecoverySigningKeyOnThisDevice
                  : context.loc.vaultRecoveryAttachSigningKey,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            Row(
              children: [
                TextButton(
                  onPressed: () => context.pushNamed(
                    BullVaultFacade.settingsRouteName,
                    pathParameters: {'walletId': walletId},
                  ),
                  child: Text(context.loc.vaultRecoveryOpenVault),
                ),
                TextButton(
                  onPressed: () => context.pushNamed(
                    BullVaultFacade.importCosignerRouteName,
                    pathParameters: {'walletId': walletId},
                  ),
                  child: Text(context.loc.bullVaultImportCosigner),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
