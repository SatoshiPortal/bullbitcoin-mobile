import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/consolidation_required_card.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_cubit.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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
        return Scaffold(
          appBar: AppBar(
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            flexibleSpace: TopBar(
              title: context.loc.consolidationScreenTitle,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Column(
            children: [
              FadingLinearProgress(
                height: 3,
                trigger: broadcasting,
                backgroundColor: context.appColors.background,
                foregroundColor: context.appColors.primary,
              ),
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
              child: ConsolidationRequiredCard(
                title: context.loc.consolidationFailedTitle,
                body: context.loc.consolidationFailedBody,
              ),
            ),
            const Gap(24),
          ],
          _Header(balanceSat: balanceSat),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BBText(
              context.loc.consolidationScreenDescription,
              style: context.font.bodyMedium,
              color: context.appColors.onSurfaceVariant,
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
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: context.appColors.onSurfaceVariant,
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
            child: BBButton.big(
              label: context.loc.consolidationScreenTitle,
              onPressed: () => context.read<ConsolidationCubit>().consolidate(),
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueText(BuildContext context, String value) => BBText(
    value,
    style: context.font.bodyLarge,
    color: context.appColors.secondary,
    textAlign: TextAlign.end,
  );

  Widget _divider(BuildContext context) =>
      Container(height: 1, color: context.appColors.secondaryFixedDim);
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
          BBText(
            title,
            style: context.font.bodySmall,
            color: context.appColors.onSurfaceVariant,
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
            color: context.appColors.secondaryFixedDim,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.sync, size: 32, color: context.appColors.secondary),
        ),
        const Gap(16),
        BBText(
          context.loc.consolidationScreenTitle,
          style: context.font.bodyMedium,
          color: context.appColors.secondary,
        ),
        const Gap(4),
        BBText(
          FormatAmount.sats(balanceSat),
          style: context.font.displaySmall,
          color: context.appColors.secondary,
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
          CircularProgressIndicator(color: context.appColors.primary),
          const Gap(24),
          BBText(
            context.loc.consolidationInProgress,
            style: context.font.headlineLarge,
            color: context.appColors.secondary,
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
            BBText(
              context.loc.consolidationSuccessTitle,
              style: context.font.headlineLarge,
              color: context.appColors.secondary,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            BBText(
              context.loc.consolidationSuccessBody,
              style: context.font.bodyMedium,
              color: context.appColors.onSurfaceVariant,
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
            const Gap(24),
            BBButton.big(
              label: context.loc.consolidationDone,
              onPressed: () => Navigator.of(context).maybePop(),
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
