import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_state.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_policy_setup_flow.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_recovery_package_share.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_completion_steps.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_schedule_dropdown.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_signer_input.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:bb_mobile/features/import_coldcard/public/import_coldcard_facade.dart';
import 'package:bb_mobile/features/import_qr_device/public/import_qr_device_facade.dart';
import 'package:bb_mobile/features/ledger/public/ledger_facade.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
              actions: state.result == null && !state.isInitialChoice
                  ? [
                      IconButton(
                        tooltip: context.loc.bullVaultAdvancedSetup,
                        onPressed: state.isCreating
                            ? null
                            : () => _showAdvanced(context),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ]
                  : null,
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
    BullVaultOnboardingStep.protectionChoice => _ProtectionChoice(state: state),
    BullVaultOnboardingStep.inheritanceChoice => _InheritanceChoice(
      state: state,
    ),
    BullVaultOnboardingStep.introduction => _Introduction(state: state),
    BullVaultOnboardingStep.coldSigner => _ColdSigner(state: state),
    BullVaultOnboardingStep.secondColdSigner => _SecondColdSigner(state: state),
    BullVaultOnboardingStep.inheritance => _Inheritance(state: state),
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
          .where((signer) => signer.signer != SignerEntity.local)
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
      onVerifySeedBackup: () => _verifySeedBackup(context, state),
      onSetUpRecoverBull: () => _setUpRecoverBull(context, state),
    ),
    BullVaultOnboardingStep.complete => BullVaultReadyStep(
      hasDeferredSetup:
          state.hardwareSetupDeferred || state.mobileBackupDeferred,
    ),
  };

  Future<void> _showAdvanced(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => BlocProvider.value(
          value: context.read<BullVaultOnboardingCubit>(),
          child: const _AdvancedSetup(),
        ),
      );
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
                BullVaultOnboardingStep.review => () => cubit.create(
                  walletLabel: context.loc.bullVaultWalletLabel,
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
                onPressed: cubit.customizeSetup,
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
      BullVaultOnboardingStep.protectionChoice => 0.05,
      BullVaultOnboardingStep.inheritanceChoice => 0.1,
      BullVaultOnboardingStep.introduction => 0.15,
      BullVaultOnboardingStep.coldSigner => 0.25,
      BullVaultOnboardingStep.secondColdSigner => 0.32,
      BullVaultOnboardingStep.inheritance => 0.4,
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

final class _ProtectionChoice extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _ProtectionChoice({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultOnboardingCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultProtectionChoiceTitle,
          style: context.font.headlineLarge,
        ),
        const Gap(12),
        Text(
          context.loc.bullVaultProtectionChoiceDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        _ChoiceTile(
          selected:
              state.protectionChoiceMade &&
              state.protection == BullVaultProtection.standard,
          label: context.loc.bullVaultProtectionStandard,
          description: context.loc.bullVaultProtectionStandardDescription,
          onTap: () => cubit.setProtection(BullVaultProtection.standard),
        ),
        const Gap(12),
        _ChoiceTile(
          selected:
              state.protectionChoiceMade &&
              state.protection == BullVaultProtection.extra,
          label: context.loc.bullVaultProtectionExtra,
          description: context.loc.bullVaultProtectionExtraDescription,
          onTap: () => cubit.setProtection(BullVaultProtection.extra),
        ),
      ],
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

final class _Introduction extends StatelessWidget {
  final BullVaultOnboardingState state;

  const _Introduction({required this.state});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        state.usesTwoColdKeys
            ? context.loc.bullVaultExtraIntroTitle
            : context.loc.bullVaultIntroTitle,
        style: context.font.headlineLarge,
      ),
      const Gap(12),
      Text(
        state.usesTwoColdKeys
            ? context.loc.bullVaultExtraIntroDescription
            : context.loc.bullVaultIntroDescription,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.textMuted,
        ),
      ),
      const Gap(24),
      _SummaryTile(
        icon: Icons.phone_iphone,
        title: context.loc.bullVaultEverydayKey,
        body: context.loc.bullVaultThisPhoneRecommended,
      ),
      const Gap(12),
      _SummaryTile(
        icon: Icons.shield_outlined,
        title: state.usesTwoColdKeys
            ? context.loc.bullVaultColdKeyOne
            : context.loc.bullVaultColdKey,
        body: context.loc.bullVaultColdKeyIntro,
      ),
      if (state.usesTwoColdKeys) ...[
        const Gap(12),
        _SummaryTile(
          icon: Icons.shield_outlined,
          title: context.loc.bullVaultColdKeyTwo,
          body: context.loc.bullVaultSecondColdKeyIntro,
        ),
      ],
      const Gap(12),
      _SummaryTile(
        icon: Icons.schedule,
        title: context.loc.bullVaultRecoveryOptions,
        body: switch ((state.protection, state.includeInheritance)) {
          (BullVaultProtection.standard, false) =>
            context.loc.bullVaultScheduleSummary(
              state.schedule.coldYears,
              state.schedule.recoveryYears,
            ),
          (BullVaultProtection.standard, true) =>
            context.loc.bullVaultInheritanceScheduleSummary(
              state.schedule.recoveryYears,
              state.schedule.coldYears,
              state.schedule.inheritanceYears,
            ),
          (BullVaultProtection.extra, false) =>
            context.loc.bullVaultExtraRecoverySummary(
              state.schedule.coldYears,
              state.schedule.recoveryYears,
            ),
          (BullVaultProtection.extra, true) =>
            context.loc.bullVaultExtraInheritanceScheduleSummary(
              state.schedule.recoveryYears,
              state.schedule.inheritanceYears,
            ),
        },
      ),
      const Gap(20),
      InfoCard(
        description: state.usesTwoColdKeys
            ? context.loc.bullVaultExtraPrimaryPathValue
            : context.loc.bullVaultPrimaryPathValue,
        tagColor: context.appColors.secondary,
        bgColor: context.appColors.onSecondary,
      ),
    ],
  );
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
          context.loc.bullVaultInheritanceKeyDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        BullVaultSignerInput(
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
          onScan: () => _scan(context, cubit.acceptInheritanceKeyAndContinue),
          usesOtherSigner: state.genericInheritanceSigner,
          onOtherSignerSelected: cubit.useGenericInheritanceSigner,
        ),
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
          icon: Icons.smartphone,
          title: context.loc.bullVaultEverydayKey,
          body: context.loc.bullVaultThisPhoneRecommended,
        ),
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
            body: state.genericInheritanceSigner
                ? context.loc.bullVaultUseOtherSigner
                : state.inheritanceDevice!.displayName,
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
            body: state.usesTwoColdKeys
                ? context.loc.bullVaultExtraTwoKeyRecoveryPathYears(
                    state.schedule.recoveryYears,
                  )
                : context.loc.bullVaultTwoKeyRecoveryPathYears(
                    state.schedule.recoveryYears,
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
            body: state.usesTwoColdKeys
                ? context.loc.bullVaultEitherColdRecoveryPathYears(
                    state.schedule.coldYears,
                  )
                : context.loc.bullVaultColdRecoveryPathYears(
                    state.schedule.coldYears,
                  ),
            secondaryBody: _recoveryDate(context, coldDate),
          ),
          const Gap(12),
          _SummaryTile(
            icon: Icons.restore,
            title: state.includeInheritance
                ? context.loc.bullVaultInheritanceRecovery
                : context.loc.bullVaultEverydayRecovery,
            body: state.includeInheritance
                ? context.loc.bullVaultInheritanceSoloPathYears(
                    state.schedule.inheritanceYears,
                  )
                : context.loc.bullVaultEverydayRecoveryPathYears(
                    state.schedule.recoveryYears,
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
            body: context.loc.bullVaultInheritanceSoloPathYears(
              state.schedule.inheritanceYears,
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
  final completed = await BullVaultPolicySetupFlow.execute(
    context,
    result: result,
    signer: signer,
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
  final verified = await context.pushNamed<bool>(
    TestWalletBackupFacade.routeName,
    extra: VerifyPhysicalBackupRequest(
      fingerprint: result.policy.everydayKey.accountKey.masterFingerprint,
    ),
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
  await RecoverBullFacade.openSetup(
    context,
    seedFingerprint: result.policy.everydayKey.accountKey.masterFingerprint,
  );
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
  Widget build(BuildContext context) {
    return BlocBuilder<BullVaultOnboardingCubit, BullVaultOnboardingState>(
      builder: (context, state) {
        final cubit = context.read<BullVaultOnboardingCubit>();
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.loc.bullVaultAdvancedSetup,
                        style: context.font.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: context.loc.closeDialogButton,
                      onPressed: context.pop,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Gap(16),
                Text(
                  context.loc.bullVaultScheduleTitle,
                  style: context.font.titleMedium,
                ),
                const Gap(8),
                Text(
                  context.loc.bullVaultScheduleDescription,
                  style: context.font.bodyMedium,
                ),
                const Gap(16),
                if (!state.usesTwoColdKeys || !state.includeInheritance) ...[
                  BullVaultScheduleDropdown(
                    label: state.usesTwoColdKeys
                        ? context.loc.bullVaultEitherColdDelay
                        : context.loc.bullVaultColdDelay,
                    value: state.schedule.coldYears,
                    values: [
                      for (
                        var year = BullVaultSchedule.minDelayYears;
                        year <= BullVaultSchedule.maxDelayYears;
                        year++
                      )
                        if (state.includeInheritance
                            ? year > state.schedule.recoveryYears &&
                                  year < state.schedule.inheritanceYears
                            : year < state.schedule.recoveryYears)
                          year,
                    ],
                    onChanged: cubit.setColdYears,
                  ),
                  const Gap(12),
                ],
                BullVaultScheduleDropdown(
                  label: !state.includeInheritance
                      ? context.loc.bullVaultEverydayDelay
                      : context.loc.bullVaultRecoveryDelay,
                  value: state.schedule.recoveryYears,
                  values: [
                    for (
                      var year = BullVaultSchedule.minDelayYears;
                      year <= BullVaultSchedule.maxDelayYears;
                      year++
                    )
                      if (state.includeInheritance
                          ? state.usesTwoColdKeys
                                ? year < state.schedule.inheritanceYears
                                : year < state.schedule.coldYears
                          : year > state.schedule.coldYears)
                        year,
                  ],
                  onChanged: cubit.setRecoveryYears,
                ),
                if (state.includeInheritance) ...[
                  const Gap(12),
                  BullVaultScheduleDropdown(
                    label: context.loc.bullVaultInheritanceDelay,
                    value: state.schedule.inheritanceYears,
                    values: [
                      for (
                        var year = BullVaultSchedule.minDelayYears;
                        year <= BullVaultSchedule.maxDelayYears;
                        year++
                      )
                        if (year >
                            (state.usesTwoColdKeys
                                ? state.schedule.recoveryYears
                                : state.schedule.coldYears))
                          year,
                    ],
                    onChanged: cubit.setInheritanceYears,
                  ),
                ],
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
    SignerDeviceEntity.coldcardQ ||
    SignerDeviceEntity.coldcardMk4 => context.pushNamed<String>(
      const ImportColdcardFacade().accountKeyRouteName(device),
      extra: ScanColdcardAccountKeyRequest(derivationPath: derivationPath),
    ),
    _ => context.pushNamed<String>(
      const ImportQrDeviceFacade().accountKeyRouteName(device),
      extra: ScanQrDeviceAccountKeyRequest(derivationPath: derivationPath),
    ),
  };
  final accountKey = await value;
  if (accountKey != null && context.mounted) await onAcquired(accountKey);
}
