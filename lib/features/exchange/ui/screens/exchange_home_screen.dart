import 'package:bb_mobile/features/exchange/presentation/exchange_home_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/bullbitcoin_webview.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_balance_cards.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeHomeScreen extends StatelessWidget {
  const ExchangeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasUser = context.select(
      (ExchangeHomeCubit cubit) => cubit.state.showExchangeHome,
    );

    if (!hasUser) return const BullbitcoinWebview();

    return const SafeArea(
      child: Column(
        children: [
          ExchangeHomeTopSection(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ExchangeHomeBalanceCards()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
