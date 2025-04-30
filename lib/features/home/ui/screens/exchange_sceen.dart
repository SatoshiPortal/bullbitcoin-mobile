import 'package:bb_mobile/features/exchange/ui/webview.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/widgets/exchange_balance_cards.dart';
import 'package:bb_mobile/features/home/ui/widgets/exchange_top_section.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeExchangeScreen extends StatelessWidget {
  const HomeExchangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasUser = context.select(
      (HomeBloc bloc) => bloc.state.showExchangeHome,
    );

    if (!hasUser) return const BullBitcoinWebViewPage();

    return const _ExchangeHome();
  }
}

class _ExchangeHome extends StatelessWidget {
  const _ExchangeHome();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        HomeExchangeTopSection(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [HomeWarnings(), HomeExchangeBalanceCards()],
            ),
          ),
        ),
      ],
    );
  }
}
