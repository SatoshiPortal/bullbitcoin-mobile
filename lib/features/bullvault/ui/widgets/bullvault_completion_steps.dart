import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

final class BullVaultRecoveryPackageStep extends StatelessWidget {
  final bool exported;
  final bool confirmed;
  final Future<void> Function() onSave;
  final Future<void> Function() onConfirm;

  const BullVaultRecoveryPackageStep({
    super.key,
    required this.exported,
    required this.confirmed,
    required this.onSave,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.description_outlined,
        size: 48,
        color: context.appColors.secondary,
      ),
      const Gap(16),
      Text(
        context.loc.bullVaultRecoveryPackageTitle,
        style: context.font.headlineLarge,
        textAlign: TextAlign.center,
      ),
      const Gap(12),
      Text(
        context.loc.bullVaultRecoveryPackageDescription,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      BBButton.big(
        label: context.loc.bullVaultSaveRecoveryData,
        onPressed: onSave,
        bgColor: context.appColors.secondary,
        textColor: context.appColors.onSecondary,
        outlined: true,
        borderColor: context.appColors.secondary,
      ),
      if (exported) ...[
        const Gap(12),
        Material(
          color: context.appColors.surfaceContainer,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: context.appColors.border),
            borderRadius: BorderRadius.circular(2),
          ),
          child: CheckboxListTile(
            value: confirmed,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(context.loc.bullVaultRecoveryPackageConfirmation),
            onChanged: confirmed ? null : (_) => onConfirm(),
          ),
        ),
      ],
    ],
  );
}

final class BullVaultHardwareSetupStep extends StatelessWidget {
  final List<WalletSigner> signers;
  final Set<String> completedSignerIds;
  final Future<void> Function(WalletSigner signer) onSetUp;

  const BullVaultHardwareSetupStep({
    super.key,
    required this.signers,
    required this.completedSignerIds,
    required this.onSetUp,
  });

  @override
  Widget build(BuildContext context) {
    final hasGenericSigner = signers.any(
      (signer) => signer.signerDevice == null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.security_outlined,
          size: 48,
          color: context.appColors.secondary,
        ),
        const Gap(16),
        Text(
          context.loc.bullVaultHardwareSetupTitle,
          style: context.font.headlineLarge,
          textAlign: TextAlign.center,
        ),
        const Gap(12),
        Text(
          context.loc.bullVaultRegistrationRequired(signers.length),
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(24),
        for (final (index, signer) in signers.indexed) ...[
          _HardwareSetupTile(
            signer: signer,
            completed: completedSignerIds.contains(signer.id),
            onComplete: () => onSetUp(signer),
          ),
          if (index != signers.length - 1) const Gap(12),
        ],
        if (hasGenericSigner) ...[
          const Gap(16),
          Text(
            context.loc.bullVaultGenericSignerWarning,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

final class BullVaultMobileBackupStep extends StatelessWidget {
  final bool seedBackupVerified;
  final bool recoverBullBackupVerified;
  final Future<void> Function() onVerifySeedBackup;
  final Future<void> Function() onSetUpRecoverBull;

  const BullVaultMobileBackupStep({
    super.key,
    required this.seedBackupVerified,
    required this.recoverBullBackupVerified,
    required this.onVerifySeedBackup,
    required this.onSetUpRecoverBull,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(Icons.backup_outlined, size: 48, color: context.appColors.secondary),
      const Gap(16),
      Text(
        context.loc.bullVaultMobileBackupTitle,
        style: context.font.headlineLarge,
        textAlign: TextAlign.center,
      ),
      const Gap(12),
      Text(
        context.loc.bullVaultMobileBackupDescription,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      _BackupOptionTile(
        completed: seedBackupVerified,
        title: seedBackupVerified
            ? context.loc.bullVaultPhysicalBackupVerified
            : context.loc.bullVaultPhysicalBackupMissing,
        description: context.loc.bullVaultPhysicalBackupDescription,
        onTap: seedBackupVerified ? null : onVerifySeedBackup,
      ),
      const Gap(12),
      _BackupOptionTile(
        completed: recoverBullBackupVerified,
        title: recoverBullBackupVerified
            ? context.loc.bullVaultRecoverBullVerified
            : context.loc.bullVaultRecoverBullMissing,
        description: context.loc.bullVaultRecoverBullDescription,
        onTap: recoverBullBackupVerified ? null : onSetUpRecoverBull,
      ),
    ],
  );
}

final class BullVaultReadyStep extends StatelessWidget {
  final bool hasDeferredSetup;

  const BullVaultReadyStep({super.key, required this.hasDeferredSetup});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Gap(32),
      Icon(
        Icons.check_circle_outline,
        size: 64,
        color: context.appColors.primary,
      ),
      const Gap(20),
      Text(
        context.loc.bullVaultCreatedTitle,
        style: context.font.headlineLarge,
        textAlign: TextAlign.center,
      ),
      const Gap(12),
      Text(
        context.loc.bullVaultCreatedDescription,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      if (hasDeferredSetup)
        InfoCard(
          description: context.loc.bullVaultDeferredSetupDescription,
          tagColor: context.appColors.warning,
          bgColor: context.appColors.warningContainer,
        )
      else
        Text(
          context.loc.bullVaultTestDeposit,
          style: context.font.bodyMedium,
          textAlign: TextAlign.center,
        ),
    ],
  );
}

final class _BackupOptionTile extends StatelessWidget {
  final bool completed;
  final String title;
  final String description;
  final Future<void> Function()? onTap;

  const _BackupOptionTile({
    required this.completed,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => BorderedTappableTile(
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          completed ? Icons.check_circle_outline : Icons.shield_outlined,
          color: completed
              ? context.appColors.primary
              : context.appColors.secondary,
        ),
        const Gap(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.font.titleSmall),
              const Gap(4),
              Text(
                description,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (!completed) ...[
          const Gap(8),
          Icon(Icons.chevron_right, color: context.appColors.textMuted),
        ],
      ],
    ),
  );
}

final class _HardwareSetupTile extends StatelessWidget {
  final WalletSigner signer;
  final bool completed;
  final Future<void> Function() onComplete;

  const _HardwareSetupTile({
    required this.signer,
    required this.completed,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) => BorderedTappableTile(
    onTap: completed ? null : onComplete,
    child: Row(
      children: [
        Icon(
          completed ? Icons.check_circle_outline : Icons.security_outlined,
          color: completed
              ? context.appColors.primary
              : context.appColors.secondary,
        ),
        const Gap(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                signer.signerDevice?.displayName ?? signer.displayFingerprint,
                style: context.font.titleSmall,
              ),
              const Gap(4),
              Text(
                completed
                    ? context.loc.bullVaultHardwareSetupComplete
                    : _setupLabel(context),
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (!completed) ...[
          const Gap(8),
          Icon(Icons.chevron_right, color: context.appColors.textMuted),
        ],
      ],
    ),
  );

  String _setupLabel(BuildContext context) {
    final device = signer.signerDevice;
    if (device == null) return context.loc.bullVaultRegisterAndConfirmNow;
    return device.isLedger || device.isBitBox
        ? context.loc.bullVaultRegisterNow
        : context.loc.bullVaultRegisterAndConfirmNow;
  }
}
