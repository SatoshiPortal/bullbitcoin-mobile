import 'package:bb_mobile/core/widgets/cards/balance_card.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ExchangeHomeBalanceCards extends StatelessWidget {
  const ExchangeHomeBalanceCards({super.key});

  @override
  Widget build(BuildContext context) {
    final balances = context.select(
      (ExchangeCubit cubit) => cubit.state.userSummary?.balances ?? [],
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
