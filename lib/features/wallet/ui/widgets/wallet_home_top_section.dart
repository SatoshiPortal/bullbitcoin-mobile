import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/action_card.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletHomeTopSection extends StatelessWidget {
  const WalletHomeTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topSectionHeight = screenHeight * 0.52;
    final uiHeight = screenHeight * 0.38;
    final cardHeight = screenHeight * 0.14;

    return SizedBox(
      height: topSectionHeight,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [SizedBox(height: uiHeight, child: const _UI())],
          ),
          Positioned(
            bottom: cardHeight * 0.4,
            left: 0,
            right: 0,
            child: SizedBox(
              height: cardHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.035,
                ),
                child: const ActionCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UI extends StatefulWidget {
  const _UI();

  @override
  State<_UI> createState() => _UIState();
}

class _UIState extends State<_UI> {
  late Image image;

  @override
  void initState() {
    image = Image.asset(Assets.backgrounds.bgRed.path, fit: BoxFit.fill);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.rotate(angle: 3.141, child: image),
        const _Amounts(),
      ],
    );
  }
}

class _Amounts extends StatelessWidget {
  const _Amounts();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topGap = screenHeight * 0.04;
    final middleGap = screenHeight * 0.015;
    final smallGap = screenHeight * 0.01;
    final sideGap = screenHeight * 0.02;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Gap(topGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Gap(sideGap),
            Gap(sideGap),
            const _BtcTotalAmt(),
            Gap(sideGap * 0.8),
            const EyeToggle(),
            const Spacer(),
          ],
        ),
        Gap(middleGap),
        const _FiatAmt(),
        Gap(smallGap),
        const _UnconfirmedIncomingBalance(),
      ],
    );
  }
}

class _BtcTotalAmt extends StatelessWidget {
  const _BtcTotalAmt();

  @override
  Widget build(BuildContext context) {
    final btcTotal = context.select(
      (WalletBloc bloc) => bloc.state.totalBalance(),
    );

    return CurrencyText(
      btcTotal,
      showFiat: false,
      style: context.font.displaySmall,
      color: context.colour.onPrimary,
    );
  }
}

class _FiatAmt extends StatelessWidget {
  const _FiatAmt();

  @override
  Widget build(BuildContext context) {
    final totalBal = context.select(
      (WalletBloc bloc) => bloc.state.totalBalance(),
    );

    return HomeFiatBalance(balanceSat: totalBal);
  }
}

class _UnconfirmedIncomingBalance extends StatelessWidget {
  const _UnconfirmedIncomingBalance();

  @override
  Widget build(BuildContext context) {
    final unconfirmed = context.select(
      (WalletBloc bloc) => bloc.state.unconfirmedIncomingBalance,
    );
    if (unconfirmed == 0) return const SizedBox.shrink();
    final color = context.colour.onPrimary;
    return GestureDetector(
      onTap: () {
        context.pushNamed(TransactionsRoute.transactions.name);
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_downward, color: color, size: 20),
                CurrencyText(
                  unconfirmed,
                  showFiat: false,
                  style: context.font.bodyLarge,
                  color: color,
                ),
              ],
            ),
            Align(
              child: Text(
                'In Progress',
                style: context.font.bodyLarge?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
