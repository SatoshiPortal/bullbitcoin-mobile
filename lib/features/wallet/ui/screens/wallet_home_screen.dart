import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletHomeScreen extends StatelessWidget {
  const WalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        WalletHomeTopSection(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [HomeWarnings(), HomeWalletCards()],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 13.0),
          child: WalletBottomButtons(),
        ),
        Gap(16),
      ],
    );
  }
}
