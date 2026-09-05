import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_state.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_policy_setup_flow.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_recovery_package_share.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_completion_steps.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_schedule_fields.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_registration_name_dialog.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final class BullVaultRenewalScreen extends StatelessWidget {
  final String walletLabel;

  const BullVaultRenewalScreen({super.key, required this.walletLabel});

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<BullVaultRenewalCubit, BullVaultRenewalState>(
    listenWhen: (previous, current) =>
        previous.failure != current.failure && current.failure != null,
    listener: (context, state) => BullSnackBar.show(
      context,
      message: state.failure!.toTranslated(context),
    ),
    builder: (context, state) {
      final isBusy =
          state.isRenewing || state.isActivating || state.isCancelling;
      final handlesBackInternally =
          state.renewal != null && state.handlesBackInternally;
      return PopScope(
        canPop: !isBusy && !handlesBackInternally,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !isBusy && handlesBackInternally) {
            context.read<BullVaultRenewalCubit>().backSetup();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.loc.bullVaultSettingsTitle),
            automaticallyImplyLeading: !isBusy,
            leading: handlesBackInternally
                ? IconButton(
                    tooltip: context.loc.backButton,
                    onPressed: isBusy
                        ? null
                        : context.read<BullVaultRenewalCubit>().backSetup,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
          ),
          body: SafeArea(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.details == null
                ? Center(child: Text(context.loc.oopsSomethingWentWrong))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      if (!state.needsInitialSetup) ...[
                        _RenewalProgress(step: state.step),
                        const Gap(24),
                      ],
                      if (state.needsInitialSetup)
                        _InitialSetup(state: state)
                      else if (state.renewal == null)
                        _RenewalReview(state: state)
                      else
                        _RenewalSetup(state: state),
                    ],
                  ),
          ),
          bottomNavigationBar: state.details != null && !state.needsInitialSetup
              ? _RenewalBottomActions(state: state, walletLabel: walletLabel)
              : null,
        ),
      );
    },
  );
}

final class _RenewalProgress extends StatelessWidget {
  final BullVaultRenewalStep step;

  const _RenewalProgress({required this.step});

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    key: const Key('bullvault-renewal-progress'),
    value: switch (step) {
      BullVaultRenewalStep.review => 0.25,
      BullVaultRenewalStep.recoveryPackage => 0.5,
      BullVaultRenewalStep.hardwareSetup => 0.7,
      BullVaultRenewalStep.activation => 0.9,
      BullVaultRenewalStep.complete => 1,
    },
    color: context.appColors.primary,
    backgroundColor: context.appColors.surfaceContainerHighest,
  );
}

final class _RenewalBottomActions extends StatelessWidget {
  final BullVaultRenewalState state;
  final String walletLabel;

  const _RenewalBottomActions({required this.state, required this.walletLabel});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BullVaultRenewalCubit>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BBButton.big(
              label: switch (state.step) {
                BullVaultRenewalStep.review => context.loc.bullVaultRenew,
                BullVaultRenewalStep.recoveryPackage ||
                BullVaultRenewalStep.hardwareSetup =>
                  context.loc.continueButton,
                BullVaultRenewalStep.activation =>
                  context.loc.bullVaultActivateRenewal,
                BullVaultRenewalStep.complete =>
                  context.loc.bullVaultOpenWallet,
              },
              onPressed: switch (state.step) {
                BullVaultRenewalStep.review => () => _confirmRenewal(context),
                BullVaultRenewalStep.recoveryPackage ||
                BullVaultRenewalStep.hardwareSetup => cubit.continueSetup,
                BullVaultRenewalStep.activation => cubit.activate,
                BullVaultRenewalStep.complete => () => context.go('/'),
              },
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
              disabled: switch (state.step) {
                BullVaultRenewalStep.review => state.isRenewing,
                BullVaultRenewalStep.recoveryPackage ||
                BullVaultRenewalStep.hardwareSetup => !state.canContinueSetup,
                BullVaultRenewalStep.activation => !state.canActivate,
                BullVaultRenewalStep.complete => false,
              },
              loading: state.isRenewing || state.isActivating,
            ),
            if (state.step == BullVaultRenewalStep.hardwareSetup &&
                !state.hardwareSetupComplete) ...[
              const Gap(8),
              BBButton.big(
                label: context.loc.bullVaultDoHardwareSetupLater,
                onPressed: () => context.go('/'),
                bgColor: context.appColors.surface,
                textColor: context.appColors.secondary,
                outlined: true,
                borderColor: context.appColors.border,
              ),
            ] else if (state.canCancel || state.isCancelling) ...[
              const Gap(4),
              TextButton(
                onPressed: state.isCancelling
                    ? null
                    : () => _confirmRenewalCancellation(context),
                child: state.isCancelling
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.loc.bullVaultCancelRenewal),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRenewal(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.bullVaultRenewConfirmationTitle),
        content: Text(context.loc.bullVaultRenewConfirmationDescription),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(context.loc.cancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(context.loc.bullVaultRenew),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<BullVaultRenewalCubit>().renew(label: walletLabel);
    }
  }

  Future<void> _confirmRenewalCancellation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.loc.bullVaultCancelRenewalTitle),
        content: Text(context.loc.bullVaultCancelRenewalDescription),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(context.loc.cancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(context.loc.bullVaultCancelRenewal),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<BullVaultRenewalCubit>().cancel();
    }
  }
}

final class _InitialSetup extends StatelessWidget {
  final BullVaultRenewalState state;

  const _InitialSetup({required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details!;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (details.policy.renewalSchedule.isPractice) ...[
          InfoCard(
            description: context.loc.bullVaultPracticeBadge,
            tagColor: context.appColors.warning,
            bgColor: context.appColors.warningContainer,
          ),
          const Gap(16),
        ],
        Text(
          context.loc.bullVaultGeneration(details.record.vaultGeneration + 1),
          style: context.font.headlineLarge,
        ),
        const Gap(24),
        InfoCard(
          description: context.loc.bullVaultFinishSetupDescription,
          tagColor: context.appColors.warning,
          bgColor: context.appColors.warningContainer,
        ),
        const Gap(12),
        BBButton.big(
          label: context.loc.bullVaultFinishSetup,
          onPressed: () async {
            await context.pushNamed(
              BullVaultFacade.createRouteName,
              queryParameters: {'walletId': details.record.walletId},
            );
            if (context.mounted) {
              await context.read<BullVaultRenewalCubit>().load();
            }
          },
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
      ],
    );
  }
}

final class _RenewalReview extends StatelessWidget {
  final BullVaultRenewalState state;

  const _RenewalReview({required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details!;
    final policy = details.policy;
    final schedule = state.schedule!;
    final reference = state.timeReference!.deviceTime;
    final currentActivations = <({String label, DateTime date})>[
      if (policy.coldActivationTimestamp case final activationTimestamp?)
        (
          label: policy.protection == BullVaultProtection.extra
              ? context.loc.bullVaultEitherColdRecoveryPath
              : context.loc.bullVaultColdRecoveryPath,
          date: _timestampDate(activationTimestamp),
        ),
      if (policy.recoveryActivationTimestamp case final activationTimestamp?)
        (
          label: policy.inheritanceKey == null
              ? context.loc.bullVaultEverydayRecovery
              : context.loc.bullVaultTwoKeyRecoveryPath,
          date: _timestampDate(activationTimestamp),
        ),
      if (policy.inheritanceActivationTimestamp case final activationTimestamp?)
        (
          label: context.loc.bullVaultInheritanceRecovery,
          date: _timestampDate(activationTimestamp),
        ),
    ]..sort((first, second) => first.date.compareTo(second.date));
    final newActivations = <({String label, DateTime date})>[
      if (policy.protection == BullVaultProtection.standard ||
          policy.inheritanceKey == null)
        (
          label: policy.protection == BullVaultProtection.extra
              ? context.loc.bullVaultEitherColdRecoveryPath
              : context.loc.bullVaultColdRecoveryPath,
          date: schedule.coldActivationDate(reference),
        ),
      (
        label: policy.inheritanceKey == null
            ? context.loc.bullVaultEverydayRecovery
            : context.loc.bullVaultTwoKeyRecoveryPath,
        date: schedule.recoveryActivationDate(reference),
      ),
      if (policy.inheritanceKey != null)
        (
          label: context.loc.bullVaultInheritanceRecovery,
          date: schedule.inheritanceActivationDate(reference),
        ),
    ]..sort((first, second) => first.date.compareTo(second.date));
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (schedule.isPractice) ...[
          InfoCard(
            description: context.loc.bullVaultPracticeBadge,
            tagColor: context.appColors.warning,
            bgColor: context.appColors.warningContainer,
          ),
          const Gap(16),
        ],
        Text(
          context.loc.bullVaultGeneration(details.record.vaultGeneration + 1),
          style: context.font.headlineLarge,
        ),
        const Gap(8),
        if (details.timeUntilFirstRecovery case final remaining?) ...[
          Text(
            context.loc.bullVaultTimeRemaining(
              remaining.inDays >= 1
                  ? context.loc.bullVaultDays(remaining.inDays)
                  : remaining.inHours >= 1
                  ? context.loc.bullVaultHours(remaining.inHours)
                  : remaining.inMinutes == 1
                  ? context.loc.durationMinute('1')
                  : context.loc.durationMinutes(
                      (remaining.inSeconds / 60).ceil().toString(),
                    ),
            ),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
        const Gap(24),
        Text(
          context.loc.bullVaultCurrentRecoveryDates,
          style: context.font.titleMedium,
        ),
        for (final activation in currentActivations) ...[
          const Gap(12),
          _ActivationRow(label: activation.label, date: activation.date),
        ],
        if (details.showEarlyRenewalWarning) ...[
          const Gap(16),
          InfoCard(
            description: context.loc.bullVaultEarlyRenewalWarning,
            tagColor: context.appColors.warning,
            bgColor: context.appColors.warningContainer,
          ),
        ],
        const Gap(24),
        Text(
          context.loc.bullVaultRenewDescription,
          style: context.font.bodyMedium,
        ),
        const Gap(24),
        BullVaultScheduleFields(
          schedule: schedule,
          usesTwoColdKeys: policy.protection == BullVaultProtection.extra,
          includeInheritance: policy.inheritanceKey != null,
          onColdChanged: (value) => context
              .read<BullVaultRenewalCubit>()
              .updateSchedule(schedule.copyWith(coldDelay: value)),
          onRecoveryChanged: (value) => context
              .read<BullVaultRenewalCubit>()
              .updateSchedule(schedule.copyWith(recoveryDelay: value)),
          onInheritanceChanged: (value) => context
              .read<BullVaultRenewalCubit>()
              .updateSchedule(schedule.copyWith(inheritanceDelay: value)),
        ),
        const Gap(24),
        Text(
          context.loc.bullVaultNewRecoveryDates,
          style: context.font.titleMedium,
        ),
        for (final activation in newActivations) ...[
          const Gap(12),
          _ActivationRow(label: activation.label, date: activation.date),
        ],
        if (details.previousVaults.isNotEmpty) ...[
          const Gap(32),
          _PreviousVaultsSection(state: state),
        ],
      ],
    );
  }

  static DateTime _timestampDate(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
}

final class _PreviousVaultsSection extends StatelessWidget {
  final BullVaultRenewalState state;

  const _PreviousVaultsSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final details = state.details!;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Text(
          context.loc.bullVaultPreviousVaultsTitle,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        Text(
          context.loc.bullVaultPreviousVaultsDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(12),
        for (final (index, previous) in details.previousVaults.indexed) ...[
          if (state.migrationTransactionIds[previous.wallet.id]
              case final transactionId?)
            _PreviousVaultTile(
              details: details,
              previous: previous,
              pendingTransactionId: transactionId,
            )
          else
            _PreviousVaultTile(details: details, previous: previous),
          if (index != details.previousVaults.length - 1) const Gap(12),
        ],
      ],
    );
  }
}

final class _PreviousVaultTile extends StatelessWidget {
  final BullVaultDetails details;
  final BullVaultPreviousVault previous;
  final String? pendingTransactionId;

  const _PreviousVaultTile({
    required this.details,
    required this.previous,
    this.pendingTransactionId,
  });

  @override
  Widget build(BuildContext context) => BorderedTappableTile(
    onTap: null,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(
            context.loc.bullVaultPreviousVaultGeneration(
              previous.record.vaultGeneration + 1,
            ),
            style: context.font.titleSmall,
          ),
          const Gap(4),
          Text(
            previous.hasFunds
                ? context.loc.bullVaultPreviousVaultBalance(
                    previous.wallet.balanceSat.toString(),
                  )
                : context.loc.bullVaultPreviousVaultEmpty,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          if (previous.hasFunds) ...[
            const Gap(12),
            InfoCard(
              description: context.loc.bullVaultMigrationDestinationLocked,
              tagColor: context.appColors.secondary,
              bgColor: context.appColors.onSecondary,
            ),
            const Gap(12),
            BBButton.big(
              label: pendingTransactionId == null
                  ? context.loc.bullVaultMoveFunds
                  : context.loc.bullVaultContinueMovingFunds,
              onPressed: () => context.pushNamed(
                SendRoute.send.name,
                extra: SendRouteArgs(
                  wallet: previous.wallet,
                  pendingTransactionId: pendingTransactionId,
                  fixedRecipient: details.migrationAddress!,
                  sendMax: pendingTransactionId == null,
                ),
              ),
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
          ],
        ],
      ),
    ),
  );
}

final class _RenewalSetup extends StatelessWidget {
  final BullVaultRenewalState state;

  const _RenewalSetup({required this.state});

  @override
  Widget build(BuildContext context) {
    final result = state.renewal!.replacement;
    return switch (state.step) {
      BullVaultRenewalStep.review => const SizedBox.shrink(),
      BullVaultRenewalStep.recoveryPackage => BullVaultRecoveryPackageStep(
        exported: state.recoveryPackageExported,
        confirmed: state.recoveryPackageConfirmed,
        onSave: () => _shareRecoveryPackage(context, state),
        onConfirm: context.read<BullVaultRenewalCubit>().confirmRecoveryPackage,
      ),
      BullVaultRenewalStep.hardwareSetup => BullVaultHardwareSetupStep(
        signers: result.wallet.signers
            .where((signer) => signer.signer == SignerEntity.remote)
            .toList(),
        completedSignerIds: state.completedSignerIds,
        onSetUp: (signer) =>
            _completeHardwareSetup(context, signerId: signer.id),
      ),
      BullVaultRenewalStep.activation => BullVaultCompletionMessage(
        title: context.loc.bullVaultRenewalPreparedTitle,
        description: context.loc.bullVaultRenewalReadyDescription,
      ),
      BullVaultRenewalStep.complete => BullVaultCompletionMessage(
        title: context.loc.bullVaultRenewalActivated,
        description: context.loc.bullVaultPreviousVaultMigrating,
      ),
    };
  }

  Future<void> _completeHardwareSetup(
    BuildContext context, {
    required String signerId,
  }) async {
    final result = state.renewal!.replacement;
    final signer = result.wallet.signers.singleWhere(
      (candidate) => candidate.id == signerId,
    );
    var setupResult = result;
    var setupSigner = signer;
    if (signer.signerDevice != null) {
      final name = await promptBullVaultRegistrationName(
        context,
        signer: signer,
        fallbackName: result.wallet.label ?? context.loc.bullVaultTitle,
      );
      if (name == null || !context.mounted) return;
      final cubit = context.read<BullVaultRenewalCubit>();
      final updated = await cubit.updateRegistrationName(
        signerId: signer.id,
        name: name,
      );
      if (!updated || !context.mounted) return;
      setupResult = cubit.state.renewal!.replacement;
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
      await context.read<BullVaultRenewalCubit>().completeSigner(signer.id);
    }
  }

  Future<void> _shareRecoveryPackage(
    BuildContext context,
    BullVaultRenewalState state,
  ) async {
    try {
      final result = state.renewal!.replacement;
      final exported = await shareBullVaultRecoveryPackage(
        context,
        content: state.recoveryPackageContent!,
        policyId: result.policy.id,
      );
      if (!context.mounted || !exported) return;
      context.read<BullVaultRenewalCubit>().markRecoveryPackageExported();
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
}

final class _ActivationRow extends StatelessWidget {
  final String label;
  final DateTime date;

  const _ActivationRow({required this.label, required this.date});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: context.font.bodyMedium)),
      const Gap(12),
      Text(
        context.loc.bullVaultRecoveryDateUtc(
          DateFormat.yMMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).add_Hm().format(date.toUtc()),
        ),
        style: context.font.bodySmall?.copyWith(
          color: context.appColors.textMuted,
        ),
      ),
    ],
  );
}
