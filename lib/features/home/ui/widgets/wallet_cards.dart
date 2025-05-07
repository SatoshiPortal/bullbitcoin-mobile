import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/home/presentation/blocs/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/home_router.dart';
import 'package:bb_mobile/ui/components/cards/wallet_card.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeWalletCards extends StatelessWidget {
  const HomeWalletCards({super.key});

  static Color cardDetails(BuildContext context, Wallet wallet) {
    final isTestnet = wallet.isTestnet;
    final isLiquid = wallet.isLiquid;
    final isWatchOnly = wallet.isWatchOnly;

    final watchonlyColor = context.colour.onPrimaryContainer;

    if (isWatchOnly && !isTestnet) return watchonlyColor;
    if (isWatchOnly && isTestnet) return watchonlyColor;

    if (isLiquid) return context.colour.tertiary;

    if (isTestnet) return context.colour.onTertiary;
    return context.colour.onTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.select((HomeBloc bloc) => bloc.state.wallets);

    return Padding(
      padding: const EdgeInsets.all(13.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in wallets) ...[
            WalletCard(
              tagColor: cardDetails(context, w),
              title: w.getLabel(),
              description: w.getWalletTypeString(),
              wallet: w,
              onTap: () {
                context.goNamed(
                  HomeRoute.walletHome.name,
                  pathParameters: {'walletId': w.id},
                  extra: context.read<HomeBloc>(),
                );
              },
            ),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}
