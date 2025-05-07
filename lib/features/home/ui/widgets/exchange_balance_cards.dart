import 'package:bb_mobile/features/home/presentation/blocs/home_bloc.dart';
import 'package:bb_mobile/ui/components/cards/balance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class HomeExchangeBalanceCards extends StatelessWidget {
  const HomeExchangeBalanceCards({super.key});

  @override
  Widget build(BuildContext context) {
    final balances = context.select(
      (HomeBloc bloc) => bloc.state.userSummary?.balances ?? [],
    );

    return Padding(
      padding: const EdgeInsets.all(13.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in balances) ...[
            BalanceCard(balance: b, onTap: () {}),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}
