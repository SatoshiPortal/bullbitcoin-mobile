import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_action_buttons.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_error.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SendSigningScreen extends StatelessWidget {
  const SendSigningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final plan = state.bitcoinSigningPlan;
    final ready = state.hasFinalizedBitcoinTransaction;
    final signingActionActive =
        state.signingTransaction || state.persistingPendingTransaction;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSigningBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: context.loc.sendSigningTitle,
            onBack: () => _handleSigningBack(context),
            backEnabled: !signingActionActive,
            action: state.isSigningSession
                ? TextButton(
                    onPressed: signingActionActive
                        ? null
                        : () => _finishSigningLater(context),
                    child: BBText(
                      context.loc.sendFinishLater,
                      style: context.font.bodyMedium,
                      color: context.appColors.secondary,
                    ),
                  )
                : null,
          ),
        ),
        body: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger:
                  state.signingTransaction ||
                  state.persistingPendingTransaction,
              backgroundColor: context.appColors.background,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SigningTransactionSummary(state: state),
                    const Gap(16),
                    BorderedTappableTile(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BBText(
                            context.loc.sendAuthorization,
                            style: context.font.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            color: context.appColors.secondary,
                          ),
                          const Gap(4),
                          BBText(
                            describeSelectedBitcoinPolicyPath(
                              context,
                              state.selectedWallet,
                              state,
                            ),
                            style: context.font.bodySmall,
                            color: context.appColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                    if (state.isSigningConflict) ...[
                      const Gap(16),
                      InfoCard(
                        title: context.loc.sendSigningConflictTitle,
                        description: context.loc.sendSigningConflictMessage,
                        tagColor: context.appColors.error,
                        bgColor: context.appColors.errorContainer,
                      ),
                    ] else if (!state.isSigningPolicyReady) ...[
                      const Gap(16),
                      InfoCard(
                        title: context.loc.sendSigningUnavailableTitle,
                        description: context.loc.sendSigningUnavailableMessage,
                        tagColor: context.appColors.error,
                        bgColor: context.appColors.errorContainer,
                      ),
                    ],
                    if (plan != null &&
                        !state.isSigningConflict &&
                        state.isSigningPolicyReady) ...[
                      const Gap(24),
                      const BitcoinSigningSection(),
                    ],
                    const Gap(24),
                    const SendError(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BBButton.big(
                  label: context.loc.sendEditTransaction,
                  onPressed: () => _confirmRestartSigning(context),
                  disabled: signingActionActive,
                  borderColor: context.appColors.secondary,
                  outlined: true,
                  bgColor: context.appColors.transparent,
                  textColor: context.appColors.secondary,
                ),
                if (ready &&
                    !state.isSigningConflict &&
                    state.isSigningPolicyReady) ...[
                  const Gap(12),
                  const ConfirmSendButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _finishSigningLater(BuildContext context) async {
  final cubit = context.read<SendCubit>();
  if (cubit.state.pendingTransactionId == null &&
      !await cubit.persistSigningSession()) {
    return;
  }
  if (context.mounted) context.pop();
}

class _SigningTransactionSummary extends StatelessWidget {
  final SendState state;

  const _SigningTransactionSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    return BorderedTappableTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            state.formattedConfirmedAmountBitcoin,
            style: context.font.headlineMedium,
            color: context.appColors.secondary,
          ),
          const Gap(8),
          BBText(
            state.paymentRequestAddress,
            style: context.font.bodySmall,
            color: context.appColors.textMuted,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(8),
          Row(
            children: [
              BBText(
                context.loc.sendNetworkFees,
                style: context.font.bodySmall,
                color: context.appColors.textMuted,
              ),
              const Spacer(),
              BBText(
                state.formattedAbsoluteFees,
                style: context.font.bodySmall,
                color: context.appColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _handleSigningBack(BuildContext context) async {
  final cubit = context.read<SendCubit>();
  final state = cubit.state;
  if (state.signingTransaction || state.persistingPendingTransaction) return;
  if (!state.isSigningSession) {
    await _confirmRestartSigning(context);
    return;
  }
  final hasSigningProgress =
      state.bitcoinSigningPlan?.hasSignatures == true ||
      state.hasFinalizedBitcoinTransaction;
  if (!hasSigningProgress) {
    context.pop();
    return;
  }
  final action = await showDialog<_SigningBackAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.sendSigningBackTitle),
      actions: [
        TextButton(
          onPressed: () =>
              dialogContext.pop(_SigningBackAction.continueSigning),
          child: Text(context.loc.sendSigningContinue),
        ),
        TextButton(
          onPressed: () => dialogContext.pop(_SigningBackAction.delete),
          child: Text(context.loc.sendSigningDeleteLocalCopy),
        ),
        TextButton(
          onPressed: () => dialogContext.pop(_SigningBackAction.keep),
          child: Text(context.loc.sendSigningKeepForLater),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case _SigningBackAction.keep:
      await _finishSigningLater(context);
    case _SigningBackAction.delete:
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.loc.sendSigningDeleteLocalCopy),
          content: Text(context.loc.sendSigningDeleteWarning),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: Text(context.loc.cancel),
            ),
            TextButton(
              onPressed: () => dialogContext.pop(true),
              child: Text(context.loc.delete),
            ),
          ],
        ),
      );
      if (confirmed == true && await cubit.deletePendingTransaction()) {
        if (context.mounted) context.pop();
      }
    case _SigningBackAction.continueSigning || null:
      break;
  }
}

Future<void> _confirmRestartSigning(BuildContext context) async {
  final state = context.read<SendCubit>().state;
  if (state.signingTransaction || state.persistingPendingTransaction) return;
  final restart = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.loc.sendSigningRestartTitle),
      content: Text(context.loc.sendSigningRestartMessage),
      actions: [
        TextButton(
          onPressed: () => dialogContext.pop(false),
          child: Text(context.loc.cancel),
        ),
        TextButton(
          onPressed: () => dialogContext.pop(true),
          child: Text(context.loc.sendSigningRestart),
        ),
      ],
    ),
  );
  if (restart == true && context.mounted) {
    await context.read<SendCubit>().restartSigningAsDraft();
  }
}

enum _SigningBackAction { keep, delete, continueSigning }
