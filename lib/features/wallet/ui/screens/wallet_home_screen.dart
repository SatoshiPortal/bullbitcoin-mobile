import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/auto_swap_fee_warning.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletHomeScreen extends StatelessWidget {
  const WalletHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Column(
        children: [
          const WalletHomeTopSection(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final bloc = context.read<WalletBloc>();
                bloc.add(const WalletRefreshed());
                await bloc.stream.firstWhere((state) => !state.isSyncing);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    const HomeWarnings(),
                    const AutoSwapFeeWarning(),
                    WalletCards(
                      onTap: (w) {
                        context.pushNamed(
                          WalletRoute.walletDetail.name,
                          pathParameters: {'walletId': w.id},
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 13.0),
            child: WalletBottomButtons(),
          ),
          const Gap(16),
        ],
      ),
    );
  }
}
