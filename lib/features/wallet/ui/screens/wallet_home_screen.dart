import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_send_receive_row.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_hero_section.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_transaction_preview.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HomeHeroSection(),
                    const HomeTransactionPreview(),
                    const Gap(16),
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
          const HomeSendReceiveRow(),
        ],
      ),
    );
  }
}
