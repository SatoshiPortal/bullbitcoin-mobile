import 'dart:async';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_state.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_policy_setup_flow.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_recovery_package_share.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_completion_steps.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_schedule_fields.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_signer_input.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_registration_name_dialog.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:bb_mobile/features/import_qr_device/public/import_qr_device_facade.dart';
import 'package:bb_mobile/features/ledger/public/ledger_facade.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart'
    show BullInputText, BullPasteInput, BullSnackBar, BullSwitch, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:screen_privacy/screen_privacy.dart';

final class BullVaultOnboardingScreen extends StatelessWidget {
  const BullVaultOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BullVaultOnboardingCubit, BullVaultOnboardingState>(
      builder: (context, state) => PopScope(
        canPop:
            state.step == BullVaultOnboardingStep.setupChoice ||
            state.step == BullVaultOnboardingStep.recoveryPackage,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !state.isCreating && !state.isActivating) {
            context.read<BullVaultOnboardingCubit>().back();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.loc.bullVaultTitle),
              leading: switch (state.step) {
                BullVaultOnboardingStep.setupChoice ||
                BullVaultOnboardingStep.recoveryPackage => const BackButton(),
                _ => IconButton(
                  tooltip: context.loc.backButton,
                  onPressed: state.isCreating || state.isActivating
                      ? null
                      : context.read<BullVaultOnboardingCubit>().back,
                  icon: const Icon(Icons.arrow_back),
                ),
              },
            ),
            body: SafeArea(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _Progress(state: state),
                  if (!state.isInitialChoice) const Gap(24),
                  _stepContent(context, state),
                  if (state.failure case final failure?) ...[
                    const Gap(16),
                    InfoCard(
                      description: failure.toTranslated(context),
                      tagColor: context.appColors.error,
                      bgColor: context.appColors.errorContainer,
                    ),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: _BottomActions(state: state),
          ),
        ),
      ),
    );
  }

  Widget _stepContent(
    BuildContext context,
    BullVaultOnboardingState state,
  ) => switch (state.step) {
    BullVaultOnboardingStep.setupChoice => const _SetupChoice(),
    BullVaultOnboardingStep.inheritanceChoice => _InheritanceChoice(
      state: state,
    ),
    BullVaultOnboardingStep.everydaySigner => _EverydaySigner(state: state),
    BullVaultOnboardingStep.coldSigner => _ColdSigner(state: state),
    BullVaultOnboardingStep.secondColdSigner => _SecondColdSigner(state: state),
    BullVaultOnboardingStep.inheritance => _Inheritance(state: state),
    BullVaultOnboardingStep.mobilePassphrase => _MobilePassphrase(state: state),
    BullVaultOnboardingStep.review => _Review(state: state),
    BullVaultOnboardingStep.recoveryPackage => BullVaultRecoveryPackageStep(
      exported: state.recoveryPackageExported,
      confirmed: state.recoveryPackageConfirmed,
      onSave: () => _shareRecoveryPackage(context, state),
      onConfirm: context
          .read<BullVaultOnboardingCubit>()
          .confirmRecoveryPackage,
    ),
    BullVaultOnboardingStep.hardwareSetup => BullVaultHardwareSetupStep(
      signers: state.result!.wallet.signers
          .where((signer) => signer.signer == SignerEntity.remote)
          .toList(),
      completedSignerIds: state.completedHardwareSignerIds,
      onSetUp: (signer) => _completeHardwareSetup(
        context,
        result: state.result!,
        signer: signer,
      ),
    ),
    BullVaultOnboardingStep.mobileBackup => BullVaultMobileBackupStep(
      seedBackupVerified: state.seedBackupVerified,
      recoverBullBackupVerified: state.recoverBullBackupVerified,
      mobilePassphraseRequired:
          state.result!.policy.everydayKey.accountKey.requiresPassphrase,
      passphraseFreeRecoveryEnabled:
          state.result!.policy.delayedMobileRecoveryKey != null,
      onVerifySeedBackup: () => _verifySeedBackup(context, state),
      onSetUpRecoverBull: () => _setUpRecoverBull(context, state),
    ),
    BullVaultOnboardingStep.complete => BullVaultReadyStep(
      hasDeferredSetup:
          state.hardwareSetupDeferred || state.mobileBackupDeferred,
    ),
  };
}

Future<void> _showBullVaultAdvancedSetup(BuildContext context) async {
  final continueSetup = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: context.read<BullVaultOnboardingCubit>(),
        child: const _AdvancedSetup(),
      ),
    ),
  );
  if (continueSetup == true && context.mounted) {
    await context.read<BullVaultOnboardingCubit>().next();
  }
}

final class _BottomActions extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _BottomActions({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BBButton.big(
              label: switch (state.step) {
                BullVaultOnboardingStep.review when state.isCreating =>
                  context.loc.bullVaultCreating,
                BullVaultOnboardingStep.review => context.loc.bullVaultCreate,
                BullVaultOnboardingStep.complete =>
                  context.loc.bullVaultOpenWallet,
                _ => context.loc.continueButton,
              },
              onPressed: switch (state.step) {
                BullVaultOnboardingStep.review => () => _createBullVault(
                  context,
                  state,
                ),
                BullVaultOnboardingStep.complete => () => _openWallet(context),
                _ => cubit.next,
              },
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
              disabled: state.step == BullVaultOnboardingStep.complete
                  ? !state.canOpenWallet
                  : !state.canContinue,
              loading:
                  state.isCreating ||
                  (state.step == BullVaultOnboardingStep.complete &&
                      state.isActivating),
            ),
            if (state.step == BullVaultOnboardingStep.setupChoice) ...[
              const Gap(8),
              BBButton.big(
                label: context.loc.bullVaultCustomizeSetup,
                onPressed: () => _showBullVaultAdvancedSetup(context),
                bgColor: context.appColors.surface,
                textColor: context.appColors.secondary,
                outlined: true,
                borderColor: context.appColors.border,
              ),
            ],
            if (state.step == BullVaultOnboardingStep.hardwareSetup &&
                !state.hardwareSetupComplete) ...[
              const Gap(8),
              BBButton.big(
                label: context.loc.bullVaultDoHardwareSetupLater,
                onPressed: () => _confirmHardwareSetupDeferral(context),
                bgColor: context.appColors.surface,
                textColor: context.appColors.secondary,
                outlined: true,
                borderColor: context.appColors.border,
              ),
            ],
            if (state.step == BullVaultOnboardingStep.mobileBackup &&
                !state.hasMobileBackup) ...[
              const Gap(8),
              BBButton.big(
                label: context.loc.bullVaultSkipMobileBackup,
                onPressed: () => _confirmMobileBackupDeferral(context),
                bgColor: context.appColors.surface,
                textColor: context.appColors.secondary,
                outlined: true,
                borderColor: context.appColors.border,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openWallet(BuildContext context) async {
    final cubit = context.read<BullVaultOnboardingCubit>();
    final activated = await cubit.activate();
    if (activated &&
        context.mounted &&
        cubit.state.step == BullVaultOnboardingStep.complete) {
      context.go('/');
    }
  }
}

Future<void> _createBullVault(
  BuildContext context,
  BullVaultOnboardingState state,
) async {
  if (state.schedule.isPractice) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.bullVaultPracticeWarningTitle),
        content: Text(context.loc.bullVaultPracticeWarningDescription),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(context.loc.cancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(context.loc.continueButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  await context.read<BullVaultOnboardingCubit>().create(
    walletLabel: state.schedule.isPractice
        ? context.loc.bullVaultPracticeBadge
        : context.loc.bullVaultWalletLabel,
  );
}

final class _SetupChoice extends StatelessWidget {
  const _SetupChoice();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _BullVaultSetupIllustration(),
      const Gap(32),
      Text(
        context.loc.bullVaultProtectionStandard,
        style: context.font.bodySmall?.copyWith(
          color: context.appColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Gap(8),
      Text(
        context.loc.bullVaultSetupChoiceTitle,
        style: context.font.headlineLarge,
      ),
      const Gap(12),
      Text(
        context.loc.bullVaultProtectionStandardDescription,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.textMuted,
        ),
      ),
      const Gap(24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SetupStep(
              icon: Icons.key_outlined,
              label: context.loc.bullVaultColdTitle,
            ),
          ),
          Expanded(
            child: _SetupStep(
              icon: Icons.schedule_outlined,
              label: context.loc.bullVaultScheduleTitle,
            ),
          ),
          Expanded(
            child: _SetupStep(
              icon: Icons.description_outlined,
              label: context.loc.bullVaultRecoveryPackageTitle,
            ),
          ),
        ],
      ),
    ],
  );
}

final class _BullVaultSetupIllustration extends StatelessWidget {
  const _BullVaultSetupIllustration();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    decoration: BoxDecoration(
      color: context.appColors.surfaceContainer,
      border: Border.all(color: context.appColors.border),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SetupIllustrationIcon(
          icon: Icons.phone_iphone_outlined,
          semanticLabel: context.loc.bullVaultEverydayKey,
        ),
        const Gap(10),
        Icon(Icons.add, color: context.appColors.textMuted, size: 20),
        const Gap(10),
        _SetupIllustrationIcon(
          icon: Icons.key_outlined,
          semanticLabel: context.loc.bullVaultColdKey,
        ),
        const Gap(14),
        Icon(Icons.arrow_forward, color: context.appColors.textMuted, size: 22),
        const Gap(14),
        _SetupIllustrationIcon(
          icon: Icons.shield_outlined,
          semanticLabel: context.loc.bullVaultTitle,
          emphasized: true,
        ),
      ],
    ),
  );
}

final class _SetupIllustrationIcon extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final bool emphasized;

  const _SetupIllustrationIcon({
    required this.icon,
    required this.semanticLabel,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      color: emphasized ? context.appColors.primary : context.appColors.surface,
      shape: BoxShape.circle,
      border: emphasized ? null : Border.all(color: context.appColors.border),
    ),
    child: Icon(
      icon,
      semanticLabel: semanticLabel,
      color: emphasized
          ? context.appColors.onPrimary
          : context.appColors.secondary,
      size: 28,
    ),
  );
}

final class _SetupStep extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SetupStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      children: [
        Icon(icon, color: context.appColors.secondary, size: 24),
        const Gap(8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

final class _Progress extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _Progress({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isInitialChoice) {
      return const SizedBox.shrink();
    }
    final value = switch (state.step) {
      BullVaultOnboardingStep.setupChoice => 0.0,
      BullVaultOnboardingStep.inheritanceChoice => 0.1,
      BullVaultOnboardingStep.everydaySigner => 0.2,
      BullVaultOnboardingStep.coldSigner => 0.25,
      BullVaultOnboardingStep.secondColdSigner => 0.32,
      BullVaultOnboardingStep.inheritance => 0.4,
      BullVaultOnboardingStep.mobilePassphrase => 0.48,
      BullVaultOnboardingStep.review => 0.55,
      BullVaultOnboardingStep.recoveryPackage => 0.68,
      BullVaultOnboardingStep.hardwareSetup => 0.8,
      BullVaultOnboardingStep.mobileBackup => 0.9,
      BullVaultOnboardingStep.complete => 1.0,
    };
    return LinearProgressIndicator(
      key: const Key('bullvault-onboarding-progress'),
      value: value,
      color: context.appColors.primary,
      backgroundColor: context.appColors.surfaceContainerHighest,
    );
  }
}

final class _InheritanceChoice extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _InheritanceChoice({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultInheritanceChoiceTitle,
          style: context.font.headlineLarge,
        ),
        const Gap(12),
        Text(
          state.usesTwoColdKeys
              ? context.loc.bullVaultExtraInheritanceChoiceDescription
              : context.loc.bullVaultInheritanceChoiceDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        _ChoiceTile(
          selected: state.inheritanceChoiceMade && state.includeInheritance,
          label: context.loc.bullVaultAddInheritance,
          description: state.usesTwoColdKeys
              ? context.loc.bullVaultExtraInheritanceDescription
              : null,
          onTap: () => cubit.setInheritance(true),
        ),
        const Gap(12),
        _ChoiceTile(
          selected: state.inheritanceChoiceMade && !state.includeInheritance,
          label: context.loc.bullVaultNoInheritance,
          onTap: () => cubit.setInheritance(false),
        ),
        if (state.usesTwoColdKeys &&
            state.inheritanceChoiceMade &&
            !state.includeInheritance) ...[
          const Gap(16),
          InfoCard(
            description: context.loc.bullVaultExtraNoInheritanceWarning,
            tagColor: context.appColors.warning,
            bgColor: context.appColors.warningContainer,
          ),
        ],
      ],
    );
  }
}

final class _EverydaySigner extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _EverydaySigner({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultEverydayKeySourceTitle,
          style: context.font.headlineLarge,
        ),
        const Gap(12),
        Text(
          context.loc.bullVaultHardwareEverydayHint,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        BullVaultSignerInput(
          device: state.everydayDevice,
          onDeviceChanged: cubit.selectEverydayDevice,
          value: state.everydayInput,
          onChanged: cubit.setEverydayInput,
          onAcquire: (device) => _acquireSignerKey(
            context,
            device: device,
            network: state.network!,
            onAcquired: cubit.acceptEverydayKeyAndContinue,
          ),
          onScan: () => _scan(context, cubit.acceptEverydayKeyAndContinue),
          usesOtherSigner: state.genericEverydaySigner,
          onOtherSignerSelected: cubit.useGenericEverydaySigner,
        ),
      ],
    );
  }
}

final class _ColdSigner extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _ColdSigner({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.loc.bullVaultColdTitle, style: context.font.headlineLarge),
        const Gap(12),
        Text(
          context.loc.bullVaultColdDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        Text(
          state.usesTwoColdKeys
              ? context.loc.bullVaultColdKeyOne
              : context.loc.bullVaultColdKey,
          style: context.font.titleMedium,
        ),
        const Gap(12),
        BullVaultSignerInput(
          device: state.coldDevice,
          onDeviceChanged: cubit.selectColdDevice,
          value: state.coldInput,
          onChanged: cubit.setColdInput,
          onAcquire: (device) => _acquireSignerKey(
            context,
            device: device,
            network: state.network!,
            onAcquired: cubit.acceptColdKeyAndContinue,
          ),
          onScan: () => _scan(context, cubit.acceptColdKeyAndContinue),
          usesOtherSigner: state.genericColdSigner,
          onOtherSignerSelected: cubit.useGenericColdSigner,
        ),
        if (!state.usesTwoColdKeys &&
            !state.includeInheritance &&
            state.isPreparingReview) ...[
          const Gap(24),
          const Center(child: CircularProgressIndicator()),
          const Gap(8),
          Center(child: Text(context.loc.bullVaultCheckingChainTime)),
        ],
      ],
    );
  }
}

final class _SecondColdSigner extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _SecondColdSigner({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultSecondColdTitle,
          style: context.font.headlineLarge,
        ),
        const Gap(12),
        Text(
          context.loc.bullVaultSecondColdDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        BullVaultSignerInput(
          device: state.secondColdDevice,
          onDeviceChanged: cubit.selectSecondColdDevice,
          value: state.secondColdInput,
          onChanged: cubit.setSecondColdInput,
          onAcquire: (device) => _acquireSignerKey(
            context,
            device: device,
            network: state.network!,
            onAcquired: cubit.acceptSecondColdKeyAndContinue,
          ),
          onScan: () => _scan(context, cubit.acceptSecondColdKeyAndContinue),
          usesOtherSigner: state.genericSecondColdSigner,
          onOtherSignerSelected: cubit.useGenericSecondColdSigner,
        ),
        if (!state.includeInheritance && state.isPreparingReview) ...[
          const Gap(24),
          const Center(child: CircularProgressIndicator()),
          const Gap(8),
          Center(child: Text(context.loc.bullVaultCheckingChainTime)),
        ],
      ],
    );
  }
}

final class _Inheritance extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _Inheritance({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultInheritanceKeyTitle,
          style: context.font.headlineLarge,
        ),
        const Gap(12),
        Text(
          context.loc.bullVaultInheritanceSourceTitle,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        for (final source in BullVaultInheritanceKeySource.values) ...[
          _ChoiceTile(
            selected: state.inheritanceSource == source,
            label: switch (source) {
              BullVaultInheritanceKeySource.hardware =>
                context.loc.bullVaultInheritanceHardware,
              BullVaultInheritanceKeySource.publicAccountKey =>
                context.loc.bullVaultInheritancePublicKey,
              BullVaultInheritanceKeySource.generatedMnemonic =>
                context.loc.bullVaultInheritanceGenerateMnemonic,
              BullVaultInheritanceKeySource.importedMnemonic =>
                context.loc.bullVaultInheritanceImportMnemonic,
            },
            onTap: () => cubit.setInheritanceSource(source),
          ),
          const Gap(12),
        ],
        const Gap(8),
        switch (state.inheritanceSource) {
          BullVaultInheritanceKeySource.hardware => BullVaultSignerInput(
            device: state.inheritanceDevice,
            onDeviceChanged: cubit.selectInheritanceDevice,
            value: state.inheritanceInput,
            onChanged: cubit.setInheritanceInput,
            onAcquire: (device) => _acquireSignerKey(
              context,
              device: device,
              network: state.network!,
              onAcquired: cubit.acceptInheritanceKeyAndContinue,
            ),
            allowOtherSigner: false,
          ),
          BullVaultInheritanceKeySource.publicAccountKey => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullPasteInput(
                text: state.inheritanceInput,
                hint: context.loc.bullVaultPublicKeyHint,
                onChanged: cubit.setInheritanceInput,
                onScan: () => _scan(
                  context,
                  (value) async => cubit.setInheritanceInput(value),
                ),
              ),
            ],
          ),
          BullVaultInheritanceKeySource.generatedMnemonic ||
          BullVaultInheritanceKeySource.importedMnemonic => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoCard(
                description: context.loc.bullVaultInheritanceMnemonicWarning,
                tagColor: context.appColors.warning,
                bgColor: context.appColors.warningContainer,
              ),
              const Gap(12),
              if (state.inheritanceInput.isNotEmpty)
                InfoCard(
                  description: context.loc
                      .bullVaultGeneratedInheritanceIdentity(
                        _inheritanceFingerprint(state.inheritanceInput),
                      ),
                  tagColor: context.appColors.secondary,
                  bgColor: context.appColors.onSecondary,
                )
              else
                BBButton.big(
                  label:
                      state.inheritanceSource ==
                          BullVaultInheritanceKeySource.generatedMnemonic
                      ? context.loc.bullVaultInheritanceGenerateMnemonic
                      : context.loc.bullVaultInheritanceImportMnemonic,
                  onPressed: () => _acquireInheritanceMnemonic(
                    context,
                    generated:
                        state.inheritanceSource ==
                        BullVaultInheritanceKeySource.generatedMnemonic,
                  ),
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                ),
            ],
          ),
        },
        if (state.isPreparingReview) ...[
          const Gap(24),
          const Center(child: CircularProgressIndicator()),
          const Gap(8),
          Center(child: Text(context.loc.bullVaultCheckingChainTime)),
        ],
      ],
    );
  }
}

final class _MobilePassphrase extends StatefulWidget {
  final BullVaultOnboardingState state;

  const _MobilePassphrase({required this.state});

  @override
  State<_MobilePassphrase> createState() => _MobilePassphraseState();
}

final class _MobilePassphraseState extends State<_MobilePassphrase>
    with PrivacyScreen {
  var _passphrase = '';
  var _confirmation = '';

  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  void _update({String? passphrase, String? confirmation}) {
    setState(() {
      _passphrase = passphrase ?? _passphrase;
      _confirmation = confirmation ?? _confirmation;
    });
    context.read<BullVaultOnboardingCubit>().setMobilePassphrase(
      _passphrase.isNotEmpty && _passphrase == _confirmation ? _passphrase : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    final mismatch = _confirmation.isNotEmpty && _passphrase != _confirmation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultPassphraseTitle,
          style: context.font.headlineLarge,
        ),
        const Gap(12),
        Text(
          context.loc.bullVaultPassphraseDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        Text(
          context.loc.bullVaultPassphraseLabel,
          style: context.font.titleSmall,
        ),
        const Gap(8),
        BullInputText(
          value: _passphrase,
          onChanged: (value) => _update(passphrase: value),
          obscure: true,
          enableSuggestions: false,
          autocorrect: false,
          smartQuotesType: SmartQuotesType.disabled,
          smartDashesType: SmartDashesType.disabled,
          maxLines: 1,
        ),
        const Gap(16),
        Text(
          context.loc.bullVaultConfirmPassphraseLabel,
          style: context.font.titleSmall,
        ),
        const Gap(8),
        BullInputText(
          value: _confirmation,
          onChanged: (value) => _update(confirmation: value),
          obscure: true,
          enableSuggestions: false,
          autocorrect: false,
          smartQuotesType: SmartQuotesType.disabled,
          smartDashesType: SmartDashesType.disabled,
          maxLines: 1,
        ),
        if (mismatch) ...[
          const Gap(8),
          Text(
            context.loc.bullVaultPassphraseMismatch,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
        const Gap(20),
        _ChoiceTile(
          selected: widget.state.passphraseFreeRecovery,
          label: context.loc.bullVaultPassphraseFreeRecoveryTitle,
          description: context.loc.bullVaultPassphraseFreeRecoveryDescription,
          onTap: () => cubit.setPassphraseFreeRecovery(
            !widget.state.passphraseFreeRecovery,
          ),
        ),
        const Gap(12),
        CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          value: widget.state.mobilePassphraseBackedUp,
          title: Text(context.loc.bullVaultPassphraseBackupAcknowledgement),
          onChanged: (value) =>
              cubit.confirmMobilePassphraseBackup(value ?? false),
        ),
      ],
    );
  }
}

String _inheritanceFingerprint(String accountKey) {
  final end = accountKey.indexOf(']');
  if (!accountKey.startsWith('[') || end <= 1) return '';
  return accountKey.substring(1, end).split('/').first.toUpperCase();
}

Future<void> _acquireInheritanceMnemonic(
  BuildContext context, {
  required bool generated,
}) async {
  final cubit = context.read<BullVaultOnboardingCubit>();
  final network = cubit.state.network;
  if (network == null) return;

  final String? accountKey;
  if (generated) {
    accountKey = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _GeneratedInheritanceMnemonicScreen(
          generateMnemonic: cubit.generateInheritanceMnemonic,
          deriveAccountKey: cubit.deriveInheritanceMnemonicKey,
        ),
      ),
    );
  } else {
    accountKey = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ImportInheritanceMnemonicScreen(
          deriveAccountKey: cubit.deriveInheritanceMnemonicKey,
        ),
      ),
    );
  }
  if (accountKey != null && context.mounted) {
    cubit.acceptInheritanceAccountKey(accountKey);
  }
}

/// Owns the mnemonic for its full lifetime and returns only its public key.
final class _GeneratedInheritanceMnemonicScreen extends StatefulWidget {
  final Result<List<String>, BullVaultFailure> Function() generateMnemonic;
  final Result<String, BullVaultFailure> Function(List<String>)
  deriveAccountKey;

  const _GeneratedInheritanceMnemonicScreen({
    required this.generateMnemonic,
    required this.deriveAccountKey,
  });

  @override
  State<_GeneratedInheritanceMnemonicScreen> createState() =>
      _GeneratedInheritanceMnemonicScreenState();
}

final class _GeneratedInheritanceMnemonicScreenState
    extends State<_GeneratedInheritanceMnemonicScreen>
    with PrivacyScreen {
  var _words = const <String>[];
  BullVaultFailure? _failure;
  late final Future<void> _privacyFuture = _protectAndGenerate();

  Future<void> _protectAndGenerate() async {
    await enableScreenPrivacy();
    if (!mounted) return;
    switch (widget.generateMnemonic()) {
      case Ok(:final value):
        _words = value;
      case Err(:final failure):
        _failure = failure;
    }
  }

  Future<void> _verify() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VerifyMnemonicScreen.forMnemonic(
          mnemonic: _words,
          title: context.loc.bullVaultInheritanceMnemonicVerifyTitle,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (!mounted || verified != true) return;
    switch (widget.deriveAccountKey(_words)) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final failure):
        BullSnackBar.show(context, message: failure.toTranslated(context));
    }
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _privacyFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          _failure == null) {
        return ShowMnemonicScreen.forMnemonic(
          mnemonic: _words,
          title: context.loc.bullVaultInheritanceMnemonicShowTitle,
          notice: context.loc.bullVaultInheritanceMnemonicWarning,
          onContinue: _verify,
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(context.loc.bullVaultInheritanceMnemonicShowTitle),
        ),
        body: Center(
          child: snapshot.connectionState != ConnectionState.done
              ? const CircularProgressIndicator()
              : Text(
                  _failure?.toTranslated(context) ??
                      context.loc.oopsSomethingWentWrong,
                ),
        ),
      );
    },
  );
}

final class _ImportInheritanceMnemonicScreen extends StatefulWidget {
  final Result<String, BullVaultFailure> Function(List<String>)
  deriveAccountKey;

  const _ImportInheritanceMnemonicScreen({required this.deriveAccountKey});

  @override
  State<_ImportInheritanceMnemonicScreen> createState() =>
      _ImportInheritanceMnemonicScreenState();
}

final class _ImportInheritanceMnemonicScreenState
    extends State<_ImportInheritanceMnemonicScreen>
    with PrivacyScreen {
  BullVaultFailure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  void _submitMnemonic(Mnemonic mnemonic) {
    switch (widget.deriveAccountKey(mnemonic.words)) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final failure):
        setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultInheritanceImportMnemonic)),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: InfoCard(
              description: context.loc.bullVaultInheritanceMnemonicWarning,
              tagColor: context.appColors.warning,
              bgColor: context.appColors.warningContainer,
            ),
          ),
          Expanded(
            child: MnemonicWidget(
              initialLength: bip39.MnemonicLength.words12,
              allowPassphrase: false,
              allowLabel: false,
              onSubmit: _submitMnemonic,
              submitLabel: context.loc.continueButton,
              externalError: _failure?.toTranslated(context),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _Review extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _Review({required this.state});

  @override
  Widget build(BuildContext context) {
    final referenceTime = state.timeReference!.deviceTime;
    final coldDate = state.schedule.coldActivationDate(referenceTime);
    final recoveryDate = state.schedule.recoveryActivationDate(referenceTime);
    final inheritanceDate = state.schedule.inheritanceActivationDate(
      referenceTime,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultReviewTitle,
          style: context.font.headlineLarge,
        ),
        const Gap(12),
        Text(
          context.loc.bullVaultReviewDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(20),
        _SummaryTile(
          icon: state.everydayKeySource == BullVaultEverydayKeySource.bullMobile
              ? Icons.smartphone
              : Icons.key_outlined,
          title: context.loc.bullVaultEverydayKey,
          body: state.everydayKeySource == BullVaultEverydayKeySource.bullMobile
              ? state.mobilePassphraseEnabled
                    ? context.loc.bullVaultPassphraseRequired
                    : context.loc.bullVaultThisPhoneRecommended
              : state.genericEverydaySigner
              ? context.loc.bullVaultUseOtherSigner
              : state.everydayDevice!.displayName,
        ),
        if (state.passphraseFreeRecovery) ...[
          const Gap(12),
          _SummaryTile(
            icon: Icons.restore,
            title: context.loc.bullVaultDelayedMobileRecovery,
            body: context.loc.bullVaultPassphraseNotRequired,
            secondaryBody: _recoveryDate(context, recoveryDate),
          ),
          const Gap(12),
          InfoCard(
            description: context.loc.bullVaultPassphraseFreeRecoveryWarning(
              DateFormat.yMMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).add_Hm().format(recoveryDate.toUtc()),
            ),
            tagColor: context.appColors.warning,
            bgColor: context.appColors.warningContainer,
          ),
        ],
        const Gap(12),
        _SummaryTile(
          icon: Icons.key,
          title: state.usesTwoColdKeys
              ? context.loc.bullVaultColdKeyOne
              : context.loc.bullVaultColdKey,
          body: state.genericColdSigner
              ? context.loc.bullVaultUseOtherSigner
              : state.coldDevice!.displayName,
        ),
        if (state.usesTwoColdKeys) ...[
          const Gap(12),
          _SummaryTile(
            icon: Icons.key,
            title: context.loc.bullVaultColdKeyTwo,
            body: state.genericSecondColdSigner
                ? context.loc.bullVaultUseOtherSigner
                : state.secondColdDevice!.displayName,
          ),
        ],
        if (state.includeInheritance) ...[
          const Gap(12),
          _SummaryTile(
            icon: Icons.family_restroom,
            title: context.loc.bullVaultInheritanceTitle,
            body: switch (state.inheritanceSource) {
              BullVaultInheritanceKeySource.hardware =>
                state.inheritanceDevice!.displayName,
              BullVaultInheritanceKeySource.publicAccountKey =>
                context.loc.bullVaultUseOtherSigner,
              BullVaultInheritanceKeySource.generatedMnemonic =>
                context.loc.bullVaultInheritanceGenerateMnemonic,
              BullVaultInheritanceKeySource.importedMnemonic =>
                context.loc.bullVaultInheritanceImportMnemonic,
            },
          ),
        ],
        const Gap(12),
        _SummaryTile(
          icon: Icons.key,
          title: context.loc.bullVaultPrimaryPath,
          body: state.usesTwoColdKeys
              ? context.loc.bullVaultExtraPrimaryPathValue
              : context.loc.bullVaultPrimaryPathValue,
        ),
        if (state.includeInheritance) ...[
          const Gap(12),
          _SummaryTile(
            icon: Icons.restore,
            title: context.loc.bullVaultTwoKeyRecoveryPath,
            body: context.loc.bullVaultDelayValue(
              _delay(context, state.schedule, state.schedule.recoveryDelay),
            ),
            secondaryBody: _recoveryDate(context, recoveryDate),
          ),
        ],
        if (!state.usesTwoColdKeys || !state.includeInheritance) ...[
          const Gap(12),
          _SummaryTile(
            icon: Icons.lock_clock,
            title: state.usesTwoColdKeys
                ? context.loc.bullVaultEitherColdRecoveryPath
                : context.loc.bullVaultColdRecoveryPath,
            body: context.loc.bullVaultDelayValue(
              _delay(context, state.schedule, state.schedule.coldDelay),
            ),
            secondaryBody: _recoveryDate(context, coldDate),
          ),
          const Gap(12),
          _SummaryTile(
            icon: Icons.restore,
            title: state.includeInheritance
                ? context.loc.bullVaultInheritanceRecovery
                : context.loc.bullVaultEverydayRecovery,
            body: context.loc.bullVaultDelayValue(
              _delay(
                context,
                state.schedule,
                state.includeInheritance
                    ? state.schedule.inheritanceDelay
                    : state.schedule.recoveryDelay,
              ),
            ),
            secondaryBody: _recoveryDate(
              context,
              state.includeInheritance ? inheritanceDate : recoveryDate,
            ),
          ),
        ] else if (state.includeInheritance) ...[
          const Gap(12),
          _SummaryTile(
            icon: Icons.restore,
            title: context.loc.bullVaultInheritanceRecovery,
            body: context.loc.bullVaultDelayValue(
              _delay(context, state.schedule, state.schedule.inheritanceDelay),
            ),
            secondaryBody: _recoveryDate(context, inheritanceDate),
          ),
        ],
        if (state.usesTwoColdKeys && !state.includeInheritance) ...[
          const Gap(16),
          InfoCard(
            description: context.loc.bullVaultExtraNoInheritanceWarning,
            tagColor: context.appColors.warning,
            bgColor: context.appColors.warningContainer,
          ),
        ],
        if (state.schedule.isPractice) ...[
          const Gap(16),
          InfoCard(
            description: context.loc.bullVaultPracticeWarningDescription,
            tagColor: context.appColors.warning,
            bgColor: context.appColors.warningContainer,
          ),
        ],
      ],
    );
  }

  String _recoveryDate(BuildContext context, DateTime activationDate) =>
      context.loc.bullVaultRecoveryDateUtc(
        DateFormat.yMMMMd(
          Localizations.localeOf(context).toLanguageTag(),
        ).add_Hm().format(activationDate.toUtc()),
      );
}

String _delay(BuildContext context, BullVaultSchedule schedule, int value) =>
    switch (schedule.unit) {
      BullVaultScheduleUnit.years => context.loc.bullVaultYears(value),
      BullVaultScheduleUnit.hours => context.loc.bullVaultHours(value),
    };

Future<void> _shareRecoveryPackage(
  BuildContext context,
  BullVaultOnboardingState state,
) async {
  try {
    final result = state.result!;
    final exported = await shareBullVaultRecoveryPackage(
      context,
      content: state.recoveryPackageContent!,
      policyId: result.policy.id,
    );
    if (!context.mounted || !exported) return;
    context.read<BullVaultOnboardingCubit>().markRecoveryPackageExported();
    BullSnackBar.show(
      context,
      message: context.loc.bullVaultRecoveryPackageExported,
    );
  } on Exception {
    if (context.mounted) {
      BullSnackBar.show(context, message: context.loc.oopsSomethingWentWrong);
    }
  }
}

Future<void> _completeHardwareSetup(
  BuildContext context, {
  required BullVaultCreateResult result,
  required WalletSigner signer,
}) async {
  var setupResult = result;
  var setupSigner = signer;
  final device = signer.signerDevice;
  if (device != null) {
    final name = await promptBullVaultRegistrationName(
      context,
      signer: signer,
      fallbackName: result.wallet.label ?? context.loc.bullVaultTitle,
    );
    if (name == null || !context.mounted) return;
    final cubit = context.read<BullVaultOnboardingCubit>();
    final updated = await cubit.updateHardwareRegistrationName(
      signerId: signer.id,
      name: name,
    );
    if (!updated || !context.mounted) return;
    setupResult = cubit.state.result!;
    setupSigner = setupResult.wallet.signers.singleWhere(
      (candidate) => candidate.id == signer.id,
    );
  }
  final completed = await BullVaultPolicySetupFlow.execute(
    context,
    result: setupResult,
    signer: setupSigner,
  );
  if (completed && context.mounted) {
    await context.read<BullVaultOnboardingCubit>().completeHardwareSigner(
      signer.id,
    );
  }
}

Future<void> _verifySeedBackup(
  BuildContext context,
  BullVaultOnboardingState state,
) async {
  final result = state.result!;
  final fingerprint = result.record.mobileSeedFingerprint;
  if (fingerprint == null) return;
  final verified = await context.pushNamed<bool>(
    TestWalletBackupFacade.routeName,
    extra: VerifyPhysicalBackupRequest(fingerprint: fingerprint),
  );
  if (verified == true && context.mounted) {
    context.read<BullVaultOnboardingCubit>().confirmSeedBackup();
  }
}

Future<void> _setUpRecoverBull(
  BuildContext context,
  BullVaultOnboardingState state,
) async {
  final result = state.result!;
  final fingerprint = result.record.mobileSeedFingerprint;
  if (fingerprint == null) return;
  await RecoverBullFacade.openSetup(context, seedFingerprint: fingerprint);
  if (context.mounted) {
    await context.read<BullVaultOnboardingCubit>().refreshMobileBackupStatus();
  }
}

Future<void> _confirmHardwareSetupDeferral(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.bullVaultDeferHardwareSetupTitle),
      content: Text(context.loc.bullVaultDeferHardwareSetupDescription),
      actions: [
        TextButton(
          onPressed: () => dialogContext.pop(false),
          child: Text(context.loc.cancel),
        ),
        TextButton(
          onPressed: () => dialogContext.pop(true),
          child: Text(context.loc.bullVaultDoHardwareSetupLater),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await context.read<BullVaultOnboardingCubit>().deferHardwareSetup();
  }
}

Future<void> _confirmMobileBackupDeferral(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.bullVaultSkipMobileBackupTitle),
      content: Text(context.loc.bullVaultSkipMobileBackupDescription),
      actions: [
        TextButton(
          onPressed: () => dialogContext.pop(false),
          child: Text(context.loc.cancel),
        ),
        TextButton(
          onPressed: () => dialogContext.pop(true),
          child: Text(context.loc.bullVaultSkipMobileBackupConfirm),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await context.read<BullVaultOnboardingCubit>().deferMobileBackup();
  }
}

final class _AdvancedSetup extends StatelessWidget {
  const _AdvancedSetup();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultAdvancedSetup)),
    body: BlocBuilder<BullVaultOnboardingCubit, BullVaultOnboardingState>(
      builder: (context, state) {
        final cubit = context.read<BullVaultOnboardingCubit>();
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AdvancedRow(
                icon:
                    state.everydayKeySource ==
                        BullVaultEverydayKeySource.bullMobile
                    ? Icons.phone_iphone_outlined
                    : Icons.key_outlined,
                title: context.loc.bullVaultEverydayKey,
                value:
                    state.everydayKeySource ==
                        BullVaultEverydayKeySource.bullMobile
                    ? context.loc.bullVaultThisPhone
                    : context.loc.bullVaultHardwareWallet,
                onTap: () => _showChoiceEditor(
                  context,
                  title: context.loc.bullVaultEverydayKeySourceTitle,
                  choices: [
                    (
                      label: context.loc.bullVaultThisPhone,
                      selected:
                          state.everydayKeySource ==
                          BullVaultEverydayKeySource.bullMobile,
                      onTap: () => cubit.setEverydayKeySource(
                        BullVaultEverydayKeySource.bullMobile,
                      ),
                    ),
                    (
                      label: context.loc.bullVaultHardwareWallet,
                      selected:
                          state.everydayKeySource ==
                          BullVaultEverydayKeySource.hardware,
                      onTap: () => cubit.setEverydayKeySource(
                        BullVaultEverydayKeySource.hardware,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              _AdvancedRow(
                icon: Icons.shield_outlined,
                title: context.loc.bullVaultProtectionChoiceTitle,
                value: state.protection == BullVaultProtection.standard
                    ? context.loc.bullVaultProtectionStandard
                    : context.loc.bullVaultProtectionExtra,
                onTap: () => _showChoiceEditor(
                  context,
                  title: context.loc.bullVaultProtectionChoiceTitle,
                  choices: [
                    (
                      label: context.loc.bullVaultProtectionStandard,
                      selected:
                          state.protection == BullVaultProtection.standard,
                      onTap: () =>
                          cubit.setProtection(BullVaultProtection.standard),
                    ),
                    (
                      label: context.loc.bullVaultProtectionExtra,
                      selected: state.protection == BullVaultProtection.extra,
                      onTap: () =>
                          cubit.setProtection(BullVaultProtection.extra),
                    ),
                  ],
                ),
              ),
              if (state.everydayKeySource ==
                  BullVaultEverydayKeySource.bullMobile) ...[
                const Gap(12),
                _AdvancedRow(
                  icon: Icons.password_outlined,
                  title: context.loc.bullVaultMobileProtection,
                  value: state.mobilePassphraseEnabled
                      ? context.loc.bullVaultUsePassphrase
                      : context.loc.bullVaultNoPassphrase,
                  onTap: () => _showChoiceEditor(
                    context,
                    title: context.loc.bullVaultMobileProtection,
                    choices: [
                      (
                        label: context.loc.bullVaultNoPassphrase,
                        selected: !state.mobilePassphraseEnabled,
                        onTap: () =>
                            cubit.setMobilePassphraseProtection(enabled: false),
                      ),
                      (
                        label: context.loc.bullVaultUsePassphrase,
                        selected: state.mobilePassphraseEnabled,
                        onTap: () => cubit.setMobilePassphraseProtection(
                          enabled: true,
                          passphraseFreeRecovery: state.passphraseFreeRecovery,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.mobilePassphraseEnabled) ...[
                  const Gap(12),
                  _AdvancedSwitchRow(
                    icon: Icons.restore_outlined,
                    title: context.loc.bullVaultDelayedMobileRecovery,
                    description:
                        context.loc.bullVaultPassphraseFreeRecoveryDescription,
                    value: state.passphraseFreeRecovery,
                    onChanged: cubit.setPassphraseFreeRecovery,
                  ),
                ],
              ],
              const Gap(12),
              _AdvancedRow(
                icon: Icons.schedule_outlined,
                title: context.loc.bullVaultScheduleTitle,
                value: context.loc.bullVaultScheduleDescription,
                onTap: () => _showScheduleEditor(context),
              ),
              const Gap(12),
              _AdvancedSwitchRow(
                icon: Icons.science_outlined,
                title: context.loc.bullVaultPracticeTimeline,
                description: context.loc.bullVaultPracticeTimelineDescription,
                value: state.schedule.isPractice,
                onChanged: cubit.setPracticeMode,
              ),
            ],
          ),
        );
      },
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: BBButton.big(
          label: context.loc.continueButton,
          onPressed: () => Navigator.of(context).pop(true),
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ),
    ),
  );
}

typedef _AdvancedChoice = ({String label, bool selected, VoidCallback onTap});

Future<void> _showChoiceEditor(
  BuildContext context, {
  required String title,
  required List<_AdvancedChoice> choices,
}) => showModalBottomSheet<void>(
  context: context,
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.font.headlineMedium),
          const Gap(16),
          for (final choice in choices) ...[
            _ChoiceTile(
              selected: choice.selected,
              label: choice.label,
              onTap: () {
                choice.onTap();
                sheetContext.pop();
              },
            ),
            const Gap(12),
          ],
        ],
      ),
    ),
  ),
);

Future<void> _showScheduleEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<BullVaultOnboardingCubit>(),
        child: const _ScheduleEditor(),
      ),
    );

final class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<BullVaultOnboardingCubit, BullVaultOnboardingState>(
        builder: (context, state) {
          final cubit = context.read<BullVaultOnboardingCubit>();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.loc.bullVaultScheduleTitle,
                    style: context.font.headlineMedium,
                  ),
                  const Gap(16),
                  BullVaultScheduleFields(
                    schedule: state.schedule,
                    usesTwoColdKeys: state.usesTwoColdKeys,
                    includeInheritance: state.includeInheritance,
                    onColdChanged: cubit.setColdYears,
                    onRecoveryChanged: cubit.setRecoveryYears,
                    onInheritanceChanged: cubit.setInheritanceYears,
                  ),
                  const Gap(20),
                  BBButton.big(
                    label: context.loc.doneButton,
                    onPressed: context.pop,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                ],
              ),
            ),
          );
        },
      );
}

final class _AdvancedRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _AdvancedRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => BorderedTappableTile(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: context.appColors.secondary),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.font.titleMedium),
              const Gap(4),
              Text(
                value,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const Gap(8),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
}

final class _AdvancedSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AdvancedSwitchRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => BorderedTappableTile(
    onTap: () => onChanged(!value),
    child: Row(
      children: [
        Icon(icon, color: context.appColors.secondary),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.font.titleMedium),
              const Gap(4),
              Text(
                description,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const Gap(8),
        BullSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

final class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? secondaryBody;

  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.body,
    this.secondaryBody,
  });

  @override
  Widget build(BuildContext context) => BorderedTappableTile(
    child: Row(
      children: [
        Icon(icon, color: context.appColors.secondary),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.font.titleMedium),
              const Gap(4),
              Text(
                body,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
              if (secondaryBody case final secondaryBody?) ...[
                const Gap(4),
                Text(
                  secondaryBody,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

final class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final String label;
  final String? description;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.selected,
    required this.label,
    this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => BorderedTappableTile(
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.font.bodyLarge),
              if (description case final description?) ...[
                const Gap(4),
                Text(
                  description,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Gap(12),
        Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected
              ? context.appColors.primary
              : context.appColors.textMuted,
        ),
      ],
    ),
  );
}

Future<void> _scan(
  BuildContext context,
  Future<void> Function(String) onScanned,
) async {
  final value = await context.pushNamed<String>(
    BullVaultRouter.scannerRouteName,
  );
  if (value != null && context.mounted) await onScanned(value);
}

Future<void> _acquireSignerKey(
  BuildContext context, {
  required SignerDeviceEntity device,
  required Network network,
  required Future<void> Function(String) onAcquired,
}) async {
  final derivationPath = Bip48Derivation.path(
    coinType: network.coinType,
    account: 0,
  );
  final value = switch (device) {
    SignerDeviceEntity.bitbox02 => context.pushNamed<String>(
      const BitBoxFacade().readAccountKeyRouteName,
      extra: ReadBitBoxAccountKeyRequest(
        deviceType: device,
        derivationPath: derivationPath,
        isTestnet: network.isTestnet,
      ),
    ),
    final ledger when ledger.isLedger => context.pushNamed<String>(
      const LedgerFacade().readAccountKeyRouteName,
      extra: ReadLedgerAccountKeyRequest(
        deviceType: ledger,
        derivationPath: derivationPath,
      ),
    ),
    _ => context.pushNamed<String>(
      const ImportQrDeviceFacade().accountKeyRouteName(device),
      extra: ScanQrDeviceAccountKeyRequest(derivationPath: derivationPath),
    ),
  };
  final accountKey = await value;
  if (accountKey != null && context.mounted) await onAcquired(accountKey);
}
