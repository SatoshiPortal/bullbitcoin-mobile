import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/eye_toggle.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapesX, BullSpacing, Gap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The total balance and how it is split between the wallets.
///
/// The card keeps the same dark surface in the light and the dark theme, so
/// the balance is the one focal point of the home screen in both.
class WalletHomeDesktopBalanceCard extends StatelessWidget {
  const WalletHomeDesktopBalanceCard({super.key, this.onOpenTransactions});

  final VoidCallback? onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = colors.onSecondaryFixed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryFixed,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.lg),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.loc.walletHomeDesktopTotalBalance,
                    style: context.font.bodyMedium?.copyWith(
                      color: foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const EyeToggle(),
              ],
            ),
            const Gap(BullSpacing.xs),
            WalletHomeBtcTotal(
              style: context.font.displayMedium?.copyWith(
                fontWeight: .w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Gap(BullSpacing.sm),
            const WalletHomeFiatTotal(),
            const Gap(BullSpacing.sm),
            _UnconfirmedIncoming(onTap: onOpenTransactions),
            const Spacer(),
            const _Split(),
          ],
        ),
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split();

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((WalletBloc bloc) => bloc.state.wallets);
    final parts = [
      for (final wallet in wallets)
        if (wallet.balanceSat case final balance? when balance > BigInt.zero)
          (
            label: wallet.displayLabel(context),
            color: WalletCards.cardDetails(context, wallet),
            sats: balance.toInt(),
          ),
    ];
    final total = parts.fold<int>(0, (sum, part) => sum + part.sats);
    if (total == 0) return const SizedBox.shrink();

    final foreground = context.appColors.onSecondaryFixed;
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.bullShapes.badge),
          child: SizedBox(
            height: 8,
            child: Row(
              crossAxisAlignment: .stretch,
              children: [
                for (final (index, part) in parts.indexed) ...[
                  if (index > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: (part.sats * 1000 / total).ceil(),
                    child: ColoredBox(color: part.color),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Gap(BullSpacing.sm),
        Wrap(
          spacing: BullSpacing.md,
          runSpacing: BullSpacing.xxs,
          children: [
            for (final part in parts)
              Row(
                mainAxisSize: .min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: part.color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 8, height: 8),
                  ),
                  const Gap(BullSpacing.xs),
                  Text(
                    '${part.label} '
                    '${(part.sats * 100 / total).toStringAsFixed(0)}%',
                    style: context.font.labelMedium?.copyWith(
                      color: foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _UnconfirmedIncoming extends StatelessWidget {
  const _UnconfirmedIncoming({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unconfirmed = context.select(
      (WalletBloc bloc) => bloc.state.unconfirmedIncomingBalance,
    );
    if (unconfirmed == 0) return const SizedBox.shrink();
    final color = context.appColors.onSecondaryFixed;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(Icons.arrow_downward, color: color, size: 18),
          const Gap(BullSpacing.xxs),
          CurrencyText(
            unconfirmed,
            showFiat: false,
            interactive: true,
            style: context.font.bodyMedium,
            color: color,
          ),
          const Gap(BullSpacing.xs),
          Flexible(
            child: Text(
              context.loc.walletBalanceUnconfirmedIncoming,
              maxLines: 1,
              overflow: .ellipsis,
              style: context.font.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
