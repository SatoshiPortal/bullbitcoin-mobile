import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/action_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ExchangeHomeTopSection extends StatelessWidget {
  const ExchangeHomeTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final balances = context.select(
      (ExchangeCubit cubit) => cubit.state.userSummary?.displayBalances ?? [],
    );
    final balanceTextStyle = switch (balances.length) {
      1 => theme.textTheme.displayMedium,
      2 => theme.textTheme.displaySmall,
      _ => theme.textTheme.headlineLarge,
    };

    final topGap = balances.length > 3 ? 32.0 : 46.0;

    return SizedBox(
      height: 264 + 78 + 46,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: .stretch,
            children: [
              Container(
                color: context.appColors.overlay,
                height: 264 + 78,
                // color: Colors.red,
                child: Stack(
                  fit: .expand,
                  children: [
                    Column(
                      mainAxisAlignment: .center,
                      children: [
                        Gap(topGap),
                        ...balances.map(
                          (b) => BBText(
                            '${b.amount} ${b.currencyCode}',
                            style: balanceTextStyle?.copyWith(
                              color: context.appColors.onPrimary,
                              fontWeight: .w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // const Gap(40),
            ],
          ),
          const Positioned(
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
