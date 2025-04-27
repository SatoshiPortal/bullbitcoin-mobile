import 'package:bb_mobile/features/home/ui/widgets/home_bottom_buttons.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/home/ui/widgets/top_section.dart';
import 'package:bb_mobile/features/home/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class HomeWalletsScreen extends StatelessWidget {
  const HomeWalletsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        HomeTopSection(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeErrors(),
                HomeWalletCards(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 13.0),
          child: HomeBottomButtons(),
        ),
        Gap(16),
      ],
    );
  }
}
