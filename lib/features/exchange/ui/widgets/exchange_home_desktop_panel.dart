import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_failure_banner.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_funding_buttons.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullPanel, BullShapesX, BullSpacing, Gap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class ExchangeHomeDesktopPanel extends StatefulWidget {
  const ExchangeHomeDesktopPanel({super.key});

  @override
  State<ExchangeHomeDesktopPanel> createState() =>
      _ExchangeHomeDesktopPanelState();
}

class _ExchangeHomeDesktopPanelState extends State<ExchangeHomeDesktopPanel> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<ExchangeCubit>();
    if (cubit.state.userSummary == null) cubit.fetchUserSummary();
  }

  @override
  Widget build(BuildContext context) {
    final isFetching = context.select(
      (ExchangeCubit cubit) => cubit.state.isFetchingUserSummary,
    );
    final loggedIn = context.select(
      (ExchangeCubit cubit) => cubit.state.hasUser,
    );

    return BullPanel(
      title: context.loc.navigationTabExchange,
      actionLabel: loggedIn ? context.loc.exchangeHomeDesktopOpen : null,
      onAction: () => context.goNamed(ExchangeRoute.exchangeHome.name),
      child: switch ((loggedIn, isFetching)) {
        (true, _) => const _Account(),
        (false, true) => const Padding(
          padding: EdgeInsets.all(BullSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        (false, false) => const _Connect(),
      },
    );
  }
}

class _Account extends StatelessWidget {
  const _Account();

  @override
  Widget build(BuildContext context) {
    final balances = context.select(
      (ExchangeCubit cubit) => cubit.state.displayBalances,
    );
    final isFullyVerified = context.select(
      (ExchangeCubit cubit) => cubit.state.isFullyVerifiedKycLevel,
    );
    final dcaActive = context.select(
      (ExchangeCubit cubit) => cubit.state.dca?.isActive ?? false,
    );
    final autoBuyActive = context.select(
      (ExchangeCubit cubit) =>
          cubit.state.userSummary?.autoBuy.isActive ?? false,
    );
    final failure = context.select(
      (ExchangeCubit cubit) => cubit.state.getUserSummaryFailure,
    );
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (failure != null) ...[
          ExchangeFailureBanner(
            failure: failure,
            onRetry: () => context.read<ExchangeCubit>().fetchUserSummary(),
          ),
          const Gap(BullSpacing.sm),
        ],
        Wrap(
          spacing: BullSpacing.xs,
          runSpacing: BullSpacing.xs,
          children: [
            if (balances.isEmpty)
              const _BalanceTile(amount: '0.00', currencyCode: '')
            else
              for (final balance in balances)
                _BalanceTile(
                  amount: balance.amount.toStringAsFixed(2),
                  currencyCode: balance.currencyCode,
                ),
          ],
        ),
        const Gap(BullSpacing.md),
        const ExchangeHomeFundingButtons(compact: true),
        const Gap(BullSpacing.md),
        _StatusLine(
          label: context.loc.exchangeHomeDesktopRecurringBuy,
          active: dcaActive,
        ),
        _StatusLine(
          label: context.loc.exchangeHomeDesktopAutoBuy,
          active: autoBuyActive,
        ),
        if (!isFullyVerified) ...[
          const Gap(BullSpacing.sm),
          const ExchangeHomeKycCard(),
        ],
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.font.bodyMedium?.copyWith(color: colors.text),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: active ? colors.success : colors.textMuted,
              shape: BoxShape.circle,
            ),
            child: const SizedBox(width: 8, height: 8),
          ),
          const Gap(BullSpacing.xs),
          Text(
            active
                ? context.loc.exchangeHomeDesktopStatusOn
                : context.loc.exchangeHomeDesktopStatusOff,
            style: context.font.bodyMedium?.copyWith(
              color: active ? colors.text : colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.amount, required this.currencyCode});

  final String amount;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BullSpacing.sm,
          vertical: BullSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Text(
              currencyCode,
              style: context.font.labelMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
            Text(
              amount,
              style: context.font.titleMedium?.copyWith(
                color: colors.text,
                fontWeight: .w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Connect extends StatelessWidget {
  const _Connect();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final features = [
      context.loc.exchangeLandingFeature1,
      context.loc.exchangeLandingFeature2,
      context.loc.exchangeLandingFeature3,
      context.loc.exchangeLandingFeature4,
    ];
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Text(
          context.loc.exchangeLandingConnect,
          style: context.font.bodyLarge?.copyWith(color: colors.text),
        ),
        const Gap(BullSpacing.sm),
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: BullSpacing.xxs),
            child: Row(
              children: [
                Icon(Icons.check, size: 16, color: colors.success),
                const Gap(BullSpacing.xs),
                Expanded(
                  child: Text(
                    feature,
                    style: context.font.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Gap(BullSpacing.md),
        BBButton.big(
          label: context.loc.exchangeLoginButton,
          onPressed: () => context.goNamed(ExchangeRoute.exchangeAuth.name),
          bgColor: colors.secondary,
          textColor: colors.onSecondary,
        ),
      ],
    );
  }
}
