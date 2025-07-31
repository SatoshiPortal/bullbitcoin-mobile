import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
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

  Wallet? _getDefaultWallet(BuildContext context) {
    final wallets = context.read<WalletBloc>().state.wallets;
    return wallets.isNotEmpty ? wallets.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: (details) {
        // Only handle horizontal swipes with sufficient velocity
        const minSwipeVelocity = 500.0;
        final velocity = details.velocity.pixelsPerSecond.dx;

        if (velocity.abs() > minSwipeVelocity) {
          final defaultWallet = _getDefaultWallet(context);

          if (velocity > 0) {
            context.pushNamed(SendRoute.send.name, extra: defaultWallet);
          } else {
            // Swipe left = Receive
            context.pushNamed(ReceiveRoute.receiveLightning.name);
          }
        }
      },
      child: Column(
        children: [
          const WalletHomeTopSection(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
