import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_cubit.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

/// Confirmation + progress screen for consolidating a Liquid wallet. Styled to
/// match the Send confirm screen (top bar, header, info rows, primary button).
///
/// Consolidation is a set of self-transactions (many outputs → a few), so it
/// broadcasts through the same Liquid pipeline as a normal send: review →
/// broadcasting → success (or the failure banner). All logic lives in
/// [ConsolidationCubit].
class ConsolidationScreen extends StatelessWidget {
  const ConsolidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConsolidationCubit, ConsolidationState>(
      builder: (context, state) {
        final broadcasting = state.status == ConsolidationStatus.broadcasting;
        return BullPage(
          topBar: BullTopBar(
            title: context.loc.consolidationScreenTitle,
            onBack: context.pop,
          ),
          child: Column(
            children: [
              if (broadcasting) const BullFadingLinearProgress(trigger: true),
              Expanded(child: _Body(state: state)),
            ],
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final ConsolidationState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ConsolidationStatus.broadcasting:
        return const _BroadcastingView();
      case ConsolidationStatus.success:
        return const _SuccessView();
      case ConsolidationStatus.idle:
      case ConsolidationStatus.failed:
        return _ReviewView(state: state);
    }
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.state});

  final ConsolidationState state;

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((WalletBloc bloc) {
      try {
        return bloc.state.wallets.firstWhere((w) => w.id == state.walletId);
      } catch (_) {
        return null;
      }
    });

    final balanceSat = wallet?.balanceSat.toInt() ?? 0;
    final before = state.utxoCount;
    final after = state.transactionCount;
    final feeSat = state.feeSat;
    const dash = '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.status == ConsolidationStatus.failed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BullInfoCard(
                title: context.loc.consolidationFailedTitle,
                description: context.loc.consolidationFailedBody,
                tagColor: context.bull.error,
                bgColor: context.bull.errorContainer,
              ),
            ),
            const Gap(24),
          ],
          _Header(balanceSat: balanceSat),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BullText(
              context.loc.consolidationScreenDescription,
              style: context.bullText.bodyMedium,
              color: context.bull.textMuted,
              textAlign: TextAlign.center,
              maxLines: 5,
            ),
          ),
          const Gap(40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoRow(
                  title: context.loc.consolidationRowOutputs,
                  details: before == null || after == null
                      ? _valueText(context, dash)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _valueText(context, '$before'),
                            const Gap(8),
                            BullIcon(
                              BullIcons.chevronRight,
                              size: 16,
                              color: context.bull.textMuted,
                            ),
                            const Gap(8),
                            _valueText(context, '$after'),
                          ],
                        ),
                ),
                _divider(context),
                _InfoRow(
                  title: context.loc.consolidationRowAmount,
                  details: _valueText(context, FormatAmount.sats(balanceSat)),
                ),
                _divider(context),
                _InfoRow(
                  title: context.loc.consolidationRowNetworkFees,
                  details: _valueText(
                    context,
                    feeSat == null ? dash : FormatAmount.sats(feeSat),
                  ),
                ),
                _divider(context),
                _InfoRow(
                  title: context.loc.consolidationRowTransactions,
                  details: _valueText(context, after == null ? dash : '$after'),
                ),
              ],
            ),
          ),
          const Gap(40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BullButton.primary(
              label: context.loc.consolidationScreenTitle,
              onPressed: () => context.read<ConsolidationCubit>().consolidate(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueText(BuildContext context, String value) => BullText(
    value,
    style: context.bullText.bodyLarge,
    color: context.bull.secondary,
    textAlign: TextAlign.end,
  );

  Widget _divider(BuildContext context) =>
      Container(height: 1, color: context.bull.outlineVariant);
}

/// Label/value row matching the Send confirm screen's `InfoRow`.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.details});

  final String title;
  final Widget details;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          BullText(
            title,
            style: context.bullText.bodySmall,
            color: context.bull.textMuted,
          ),
          const Gap(24),
          Expanded(child: details),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.balanceSat});

  final int balanceSat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: context.bull.secondaryFixedDim,
            shape: BoxShape.circle,
          ),
          child: BullIcon(
            BullIcons.sync,
            size: 32,
            color: context.bull.secondary,
          ),
        ),
        const Gap(16),
        BullText(
          context.loc.consolidationScreenTitle,
          style: context.bullText.bodyMedium,
          color: context.bull.secondary,
        ),
        const Gap(4),
        BullText(
          FormatAmount.sats(balanceSat),
          style: context.bullText.displaySmall,
          color: context.bull.secondary,
        ),
      ],
    );
  }
}

class _BroadcastingView extends StatelessWidget {
  const _BroadcastingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BullFadingLinearProgress(trigger: true),
          const Gap(24),
          BullText(
            context.loc.consolidationInProgress,
            style: context.bullText.headlineLarge,
            color: context.bull.secondary,
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BullText(
              context.loc.consolidationSuccessTitle,
              style: context.bullText.headlineLarge,
              color: context.bull.secondary,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            BullText(
              context.loc.consolidationSuccessBody,
              style: context.bullText.bodyMedium,
              color: context.bull.textMuted,
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
            const Gap(24),
            BullButton.primary(
              label: context.loc.consolidationDone,
              onPressed: context.pop,
            ),
          ],
        ),
      ),
    );
  }
}
