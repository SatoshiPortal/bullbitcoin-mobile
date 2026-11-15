import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_carousel.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/consolidation/public/consolidation_facade.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_refresh_body.dart';

class WalletHomeMobileBody extends StatelessWidget {
  const WalletHomeMobileBody({super.key});

  /// Height the pinned Receive/Send bar occupies
  static const double _bottomBarHeight = 52.0 + 16.0 * 2;

  @override
  Widget build(BuildContext context) {
    final isRefreshing = context.select(
      (WalletBloc bloc) => bloc.state.isRefreshing,
    );
    return Stack(
      children: [
        // Black background visible only during iOS top overscroll
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ColoredBox(
            color: AppColors.dark.background,
            child: const SizedBox(height: 300),
          ),
        ),
        WalletRefreshBody(
          isRefreshing: isRefreshing,
          waitForRefresh: context.read<WalletBloc>().waitForRefresh,
          onRefresh: () {
            context.read<BitcoinPriceBloc>().add(const BitcoinPriceFetched());
            return context.read<WalletBloc>().refresh();
          },
          // Clearance for the bar pinned at the bottom of this Stack, so
          // the last wallet card can be scrolled out from under it.
          bottomInset: _bottomBarHeight + MediaQuery.paddingOf(context).bottom,
          slivers: [
            // Pinned rather than scrolled away: the balance and the
            // Buy/Sell/Pay/Transfer actions stay put while the wallet cards
            // scroll underneath.
            const PinnedHeaderSliver(child: WalletHomeTopSection()),
            const SliverToBoxAdapter(child: AnnouncementCarousel()),
            const SliverToBoxAdapter(child: HomeWarnings()),
            const SliverToBoxAdapter(child: HomeConsolidationBanner()),
            SliverToBoxAdapter(
              child: WalletCards(
                onTap: (w) {
                  context.pushNamed(
                    WalletRoute.walletDetail.name,
                    pathParameters: {'walletId': w.id},
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 13.0,
                vertical: 16.0,
              ),
              child: WalletBottomButtons(),
            ),
          ),
        ),
      ],
    );
  }
}
