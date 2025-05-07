import 'package:bb_mobile/features/home/presentation/blocs/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_bottom_buttons.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_wallet_balance_card.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_wallet_txs_list.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomeWalletScreen extends StatelessWidget {
  const HomeWalletScreen({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context) {
    final wallet = context.select(
      (HomeBloc bloc) => bloc.state.wallets.firstWhere((w) => w.id == walletId),
    );
    final walletName =
        wallet.isDefault
            ? wallet.isLiquid
                ? // TODO: use labels from translations for hardcoded names here
                "Instant wallet"
                : "Secure Bitcoin wallet"
            : wallet.label;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(title: walletName, onBack: context.pop),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            children: [
              HomeWalletBalanceCard(
                balanceSat: wallet.balanceSat.toInt(),
                isLiquid: wallet.isLiquid,
              ),
              const Gap(16.0),
              const HomeWalletTxsList(),
              const Gap(96),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 13.0, vertical: 40),
            child: HomeBottomButtons(),
          ),
        ],
      ),
    );
  }
}
