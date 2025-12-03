import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
    return const SizedBox(
      height: 264 + 78 + 46,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: .stretch,
            children: [
              SizedBox(
                height: 264 + 78,
                // color: Colors.red,
                child: _UI(),
              ),
              // const Gap(40),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 13.0),
              child: ActionCard(),
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
    image = Image.asset(Assets.backgrounds.bgRed.path, fit: .fill);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: .expand, children: [image, const _Amounts()]);
  }
}

class _Amounts extends StatelessWidget {
  const _Amounts();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: .center,
      children: [
        Gap(32),
        Row(
          mainAxisAlignment: .center,
          children: [Spacer(), _BtcTotalAmt(), Gap(16), EyeToggle(), Spacer()],
        ),
        Gap(12),
        _FiatAmt(),
        Gap(8),
        _UnconfirmedIncomingBalance(),
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
      color: context.appColors.onPrimary,
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
    final color = context.appColors.onPrimary;
    return GestureDetector(
      onTap: () {
        context.pushNamed(TransactionsRoute.transactions.name);
      },
      child: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            Row(
              mainAxisSize: .min,
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
                context.loc.walletBalanceUnconfirmedIncoming,
                style: context.font.bodyLarge?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
