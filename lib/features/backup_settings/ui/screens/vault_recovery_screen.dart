import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_result.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_source_rows.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullInfoCard, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Where recovering a vault starts.
///
/// The automatic search runs on this device's own backup credential and reports
/// each source on its own; the four manual entries stay available throughout,
/// including on a phone with no seed, where the automatic search cannot run at
/// all. Every validated vault is imported as it is found, through the same
/// importer every other route uses.
class VaultRecoveryScreen extends StatelessWidget {
  const VaultRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.vaultRecoveryTitle)),
    body: SafeArea(
      child: BlocBuilder<VaultRecoveryCubit, VaultRecoveryState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (state.credentialAvailable == false)
              BullInfoCard(
                description: context.loc.vaultRecoveryNoCredential,
                tagColor: context.appColors.warning,
                bgColor: context.appColors.warningContainer,
              )
            else ...[
              Text(
                context.loc.vaultRecoveryDescription,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              const Gap(24),
              VaultRecoverySourceRows(sources: state.sources),
            ],
            const Gap(16),
            VaultRecoveryResultView(outcomes: state.outcomes),
            const Gap(32),
            Text(
              context.loc.vaultRecoveryManualTitle,
              style: context.font.titleMedium,
            ),
            const Gap(8),
            _Entry(
              icon: Icons.description_outlined,
              title: context.loc.vaultRecoveryImportDescriptor,
              description: context.loc.vaultRecoveryImportDescriptorDescription,
              route: BullVaultFacade.importDescriptorRouteName,
            ),
            _Entry(
              icon: Icons.key_outlined,
              title: context.loc.vaultRecoveryImportCosignerKey,
              description:
                  context.loc.vaultRecoveryImportCosignerKeyDescription,
              route: BackupSettingsSubroute.vaultRecoveryCosignerKey.name,
            ),
            _Entry(
              icon: Icons.password_outlined,
              title: context.loc.vaultRecoveryImportBackupWords,
              description:
                  context.loc.vaultRecoveryImportBackupWordsDescription,
              route: BackupSettingsSubroute.vaultRecoveryBackupWords.name,
            ),
            _Entry(
              icon: Icons.phone_iphone_outlined,
              title: context.loc.vaultRecoveryImportMobileKey,
              description: context.loc.vaultRecoveryImportMobileKeyDescription,
              route: BackupSettingsSubroute.vaultRecoveryMobileKey.name,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Entry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String route;

  const _Entry({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SettingsEntryItem(
        icon: icon,
        title: title,
        onTap: () => context.pushNamed(route),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 40, bottom: 12),
        child: Text(
          description,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
