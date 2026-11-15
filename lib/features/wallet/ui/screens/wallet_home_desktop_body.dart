import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_carousel.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_card.dart';
import 'package:bb_mobile/features/consolidation/public/consolidation_facade.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_desktop_balance_card.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullPanel, BullSpacing, BullSyncButton, Gap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show NetworkCapability;

class WalletHomeDesktopBody extends StatelessWidget {
  const WalletHomeDesktopBody({super.key, required this.config});

  final WalletHomeDesktopConfig config;

  static const double _maxContentWidth = 1280;
  static const double _gutter = BullSpacing.xl;
  static const double _gap = BullSpacing.lg;
  static const double _overviewHeight = 300;

  /// The notice widgets carry their own 13 px side padding.
  static const double _noticeGutter = _gutter - 13;

  @override
  Widget build(BuildContext context) {
    final exchangePanel = config.buildExchangePanel?.call(context);
    final recentTransactions = config.buildRecentTransactions?.call(context);
    final onOpenTransactions = config.onOpenTransactions;

    final wallets = BullPanel(
      title: context.loc.walletHomeDesktopWallets,
      child: WalletCards(
        dense: true,
        onTap: (w) => context.pushNamed(
          WalletRoute.walletDetail.name,
          pathParameters: {'walletId': w.id},
        ),
      ),
    );

    return ColoredBox(
      color: context.appColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: _gutter),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gutter),
                  child: _Header(config: config),
                ),
                const Gap(_gap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gutter),
                  child: SizedBox(
                    height: _overviewHeight,
                    child: Row(
                      crossAxisAlignment: .stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: WalletHomeDesktopBalanceCard(
                            onOpenTransactions: onOpenTransactions == null
                                ? null
                                : () => onOpenTransactions(context),
                          ),
                        ),
                        const Gap(_gap),
                        const Expanded(flex: 7, child: PriceChartCard()),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: _noticeGutter),
                  child: Column(
                    children: [
                      AnnouncementCarousel(),
                      HomeWarnings(),
                      HomeConsolidationBanner(),
                    ],
                  ),
                ),
                const Gap(_gap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gutter),
                  child: NetworkCapabilityBuilder(
                    capability: NetworkCapability.exchange,
                    builder: (context, exchangeSupported) {
                      if (exchangePanel == null || !exchangeSupported) {
                        return wallets;
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: .stretch,
                          children: [
                            Expanded(flex: 7, child: wallets),
                            const Gap(_gap),
                            Expanded(flex: 5, child: exchangePanel),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (recentTransactions != null) ...[
                  const Gap(_gap),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _gutter),
                    child: recentTransactions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.config});

  final WalletHomeDesktopConfig config;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isRefreshing = context.select(
      (WalletBloc bloc) => bloc.state.isRefreshing,
    );
    final actions = config.buildActions?.call(context) ?? const [];
    final buttonStyle = context.font.bodyLarge?.copyWith(fontWeight: .w600);

    return Row(
      children: [
        Text(
          context.loc.navigationHome,
          style: context.font.headlineLarge?.copyWith(
            color: colors.text,
            fontSize: 28,
            fontWeight: .w600,
          ),
        ),
        const Gap(BullSpacing.md),
        BullSyncButton(
          label: context.loc.walletHomeDesktopSync,
          syncing: isRefreshing,
          color: colors.textMuted,
          onPressed: () {
            context.read<BitcoinPriceBloc>().add(const BitcoinPriceFetched());
            context.read<WalletBloc>().refresh();
          },
        ),
        const Spacer(),
        NetworkCapabilityVisibility(
          capability: NetworkCapability.exchange,
          child: Row(
            mainAxisSize: .min,
            children: [
              for (final action in actions) ...[
                BullButton.small(
                  label: action.label,
                  iconData: action.icon,
                  iconFirst: true,
                  compact: true,
                  outlined: true,
                  bgColor: colors.surface,
                  textColor: colors.text,
                  borderColor: colors.outlineVariant,
                  textStyle: buttonStyle,
                  onPressed: action.onTap,
                ),
                const Gap(BullSpacing.xs),
              ],
              const Gap(BullSpacing.xs),
            ],
          ),
        ),
        BullButton.small(
          label: context.loc.walletButtonReceive,
          iconData: Icons.arrow_downward,
          iconFirst: true,
          compact: true,
          bgColor: colors.secondary,
          textColor: colors.onSecondary,
          textStyle: buttonStyle,
          onPressed: () => context.pushNamed(ReceiveRoute.receiveBitcoin.name),
        ),
        const Gap(BullSpacing.xs),
        BullButton.small(
          label: context.loc.walletButtonSend,
          iconData: Icons.arrow_upward,
          iconFirst: true,
          compact: true,
          bgColor: colors.secondary,
          textColor: colors.onSecondary,
          textStyle: buttonStyle,
          onPressed: () => context.pushNamed(SendRoute.send.name),
        ),
      ],
    );
  }
}
