import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/fees/fee_options_modal.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_cubit.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_failure_l10n.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_state.dart';
import 'package:bb_mobile/features/sweep/ui/sweep_amount_format.dart';
import 'package:bb_mobile/features/sweep/ui/widgets/sweep_change_address_sheet.dart';
import 'package:bb_mobile/features/sweep/ui/widgets/sweep_recipient_card.dart';
import 'package:bb_mobile/features/sweep/ui/widgets/sweep_review_body.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The sweep flow: split the selected coins across recipients, review the built
/// transaction, broadcast. Built entirely on `package:bull_ui/bull_ui.dart`.
class SweepScreen extends StatelessWidget {
  const SweepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SweepCubit, SweepState>(
      listenWhen: (prev, curr) =>
          prev.failure != curr.failure && curr.failure != null,
      listener: (context, state) {
        final failure = state.failure;
        if (failure == null) return;
        BullSnackBar.show(context, message: failure.toTranslated(context));
        context.read<SweepCubit>().clearFailure();
      },
      builder: (context, state) => switch (state.step) {
        SweepStep.allocate => _AllocateView(state: state),
        SweepStep.review => _ReviewView(state: state),
        SweepStep.success => _SuccessView(state: state),
      },
    );
  }
}

// ── Step 1: allocation ──────────────────────────────────────────────────────

class _AllocateView extends StatelessWidget {
  const _AllocateView({required this.state});

  final SweepState state;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.bull;
    final cubit = context.read<SweepCubit>();
    final bitcoinUnit =
        context.select((SettingsCubit c) => c.state.bitcoinUnit) ??
        BitcoinUnit.btc;

    return BullScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BullTopBar(title: loc.sweepTitle, onBack: context.pop),
            Expanded(
              child: BullScrollableColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _TotalCard(state: state, bitcoinUnit: bitcoinUnit),
                  const Gap(16),
                  for (var i = 0; i < state.allocations.length; i++)
                    SweepRecipientCard(
                      key: ValueKey('sweep-recipient-$i'),
                      index: i,
                      allocation: state.allocations[i],
                      bitcoinUnit: bitcoinUnit,
                      remainderSat: _remainderFor(i),
                      canRemove: state.allocations.length > 1,
                      onAddressChanged: (value) =>
                          cubit.addressChanged(i, value),
                      onAmountChanged: (value) => cubit.amountChanged(i, value),
                      onTakeRemainder: () => cubit.takeRemainder(i),
                      onReleaseRemainder: () => cubit.releaseRemainder(i),
                      onRemove: () => cubit.removeRecipient(i),
                      onPickChangeAddress: state.ownChangeAddresses.isEmpty
                          ? null
                          : () => _pickChangeAddress(context, state, i),
                    ),
                  GestureDetector(
                    onTap: cubit.addRecipient,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BullIcon(
                            BullIcons.add,
                            size: 18,
                            color: colors.primary,
                          ),
                          const Gap(6),
                          Text(
                            loc.sweepAddRecipient,
                            style: context.bullText.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(8),
                  _AllocationSummary(state: state, bitcoinUnit: bitcoinUnit),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: BullButton.big(
            label: state.building ? loc.sweepBuilding : loc.sweepReviewAction,
            disabled: !state.canReview,
            onPressed: cubit.review,
            bgColor: colors.primary,
            textColor: colors.onPrimary,
          ),
        ),
      ),
    );
  }

  void _pickChangeAddress(BuildContext context, SweepState state, int index) {
    final cubit = context.read<SweepCubit>();
    BullBottomSheet.show<void>(
      context: context,
      child: SweepChangeAddressSheet(
        addresses: state.ownChangeAddresses,
        onSelected: (address) {
          cubit.addressChanged(index, address.address);
          context.pop();
        },
      ),
    );
  }

  /// What row [index] would receive if it took the remainder: everything the
  /// *other* pinned rows leave behind, fee not yet deducted.
  BigInt _remainderFor(int index) {
    var allocated = BigInt.zero;
    for (var i = 0; i < state.allocations.length; i++) {
      if (i == index) continue;
      final row = state.allocations[i];
      if (!row.takesRemainder && row.amountSat != null) {
        allocated += row.amountSat!;
      }
    }
    final remainder = state.totalInputSat - allocated;
    return remainder.isNegative ? BigInt.zero : remainder;
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.state, required this.bitcoinUnit});

  final SweepState state;
  final BitcoinUnit bitcoinUnit;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(BullRadius.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.sweepCoinsCount(state.inputs.length),
            style: context.bullText.labelMedium?.copyWith(
              color: colors.textMuted,
            ),
          ),
          const Gap(4),
          Text(
            formatSweepAmount(state.totalInputSat, bitcoinUnit),
            style: context.bullText.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const Gap(6),
          Text(
            context.loc.sweepSpentEntirely,
            style: context.bullText.bodySmall?.copyWith(
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable fee row on the review step, opening the shared fee modal.
///
/// Lives here rather than on the allocation step on purpose: the modal prices
/// each preset by building a real PSBT, which needs a valid plan. That is also
/// where `send` puts it, so both flows behave the same.
class _ReviewFeeRow extends StatelessWidget {
  const _ReviewFeeRow({required this.state, required this.bitcoinUnit});

  final SweepState state;
  final BitcoinUnit bitcoinUnit;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;
    final quote = state.quote;
    final label = switch (state.selectedFeeOption) {
      FeeSelection.fastest => FeeSelection.fastest.title(),
      FeeSelection.economic => FeeSelection.economic.title(),
      FeeSelection.slow => FeeSelection.slow.title(),
      FeeSelection.custom => FeeSelection.custom.title(),
    };

    return GestureDetector(
      onTap: state.feePresets == null || state.building
          ? null
          : () => _openFeeModal(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(BullRadius.xs),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.sweepNetworkFee,
                    style: context.bullText.labelLarge?.copyWith(
                      color: colors.text,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    label,
                    style: context.bullText.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (state.building || quote == null)
              const BullShimmerLine(
                width: 90,
                height: 12,
                padding: EdgeInsets.zero,
              )
            else
              Text(
                '${formatSweepAmount(quote.feeSat, bitcoinUnit)} · '
                '${loc.sweepFeeRate(quote.satPerVbyte.toStringAsFixed(2))}',
                style: context.bullText.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            const Gap(4),
            BullIcon(BullIcons.chevronRight, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  /// Shows the shared modal from `core/widgets/fees/`, the same one send, sell
  /// and swap use. [SweepCubit] implements both of its ports.
  void _openFeeModal(BuildContext context) {
    final cubit = context.read<SweepCubit>();
    final colors = context.bull;
    BullBottomSheet.show<void>(
      context: context,
      child: FeeOptionsModal(
        viewState: cubit,
        actions: cubit,
        defaultAbsoluteCustomFee: false,
        customFeeColors: FeeModalCustomFeeColors(
          tile: colors.surface,
          shadow: colors.scrim,
          unselectedIcon: colors.outlineVariant,
        ),
      ),
    ).then((_) {
      // Dismissal commits a valid typed rate, or rolls back to the previous
      // selection — the modal's documented contract.
      cubit.finalizeArmedCustomFee();
    });
  }
}

/// Live arithmetic of the split, so the user always knows where the balance is.
class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({required this.state, required this.bitcoinUnit});

  final SweepState state;
  final BitcoinUnit bitcoinUnit;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.bull;
    final unallocated = state.unallocatedSat;

    return Column(
      children: [
        _SummaryLine(
          label: loc.sweepAllocated,
          value: formatSweepAmount(state.allocatedSat, bitcoinUnit),
        ),
        const Gap(6),
        _SummaryLine(
          label: state.hasRemainderRow
              ? loc.sweepRemainderToRecipient
              : loc.sweepChangeBackToWallet,
          value: unallocated.isNegative
              ? formatSweepAmount(BigInt.zero, bitcoinUnit)
              : formatSweepAmount(unallocated, bitcoinUnit),
          emphasise: true,
        ),
        if (state.isOverAllocated) ...[
          const Gap(10),
          BullInfoBar(
            message: loc.sweepOverAllocatedWarning,
            tone: BullInfoTone.warning,
          ),
        ] else if (!state.hasRemainderRow) ...[
          const Gap(8),
          Text(
            loc.sweepChangeExplainer,
            style: context.bullText.bodySmall?.copyWith(
              color: colors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final style = context.bullText.labelMedium?.copyWith(
      color: emphasise ? colors.text : colors.textMuted,
      fontWeight: emphasise ? FontWeight.w600 : FontWeight.w400,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

// ── Step 2: review ──────────────────────────────────────────────────────────

class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.state});

  final SweepState state;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.bull;
    final cubit = context.read<SweepCubit>();
    final bitcoinUnit =
        context.select((SettingsCubit c) => c.state.bitcoinUnit) ??
        BitcoinUnit.btc;
    final quote = state.quote;

    return BullScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BullTopBar(
              title: loc.sweepReviewTitle,
              onBack: cubit.backToAllocation,
            ),
            Expanded(
              child: quote == null
                  ? const SizedBox.shrink()
                  : SweepReviewBody(
                      quote: quote,
                      bitcoinUnit: bitcoinUnit,
                      feeRow: _ReviewFeeRow(
                        state: state,
                        bitcoinUnit: bitcoinUnit,
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: BullButton.big(
            label: state.broadcasting
                ? loc.sweepBroadcasting
                : loc.sweepConfirmAction,
            disabled: state.broadcasting || quote == null,
            onPressed: cubit.confirm,
            bgColor: colors.primary,
            textColor: colors.onPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Step 3: success ─────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.state});

  final SweepState state;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.bull;
    return BullSuccessScreen(
      title: loc.sweepTitle,
      headline: loc.sweepSuccessHeadline,
      onClose: context.pop,
      icon: BullIcon(BullIcons.checkCircle, size: 64, color: colors.success),
      message: state.txId == null
          ? null
          : BullDetailsTable(
              items: [
                BullDetailsTableItem(
                  label: loc.sweepSuccessTxId,
                  displayValue: state.txId,
                  copyValue: state.txId,
                  copiedMessage: loc.addressCardCopiedMessage,
                ),
              ],
            ),
    );
  }
}
