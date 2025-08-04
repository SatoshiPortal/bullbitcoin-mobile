import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/action_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ExchangeHomeTopSection extends StatelessWidget {
  const ExchangeHomeTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return SizedBox(
      height: 264 + 78 + 46,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.black,
                height: 264 + 78,
                // color: Colors.red,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Gap(46),
                        BlocBuilder<ExchangeCubit, ExchangeState>(
                          buildWhen: (previous, current) {
                            final prevBalances =
                                previous.userSummary?.displayBalances ?? [];
                            final currentBalances =
                                current.userSummary?.displayBalances ?? [];
                            return prevBalances.length !=
                                    currentBalances.length ||
                                !listEquals(
                                  prevBalances
                                      .map(
                                        (b) => '${b.amount}${b.currencyCode}',
                                      )
                                      .toList(),
                                  currentBalances
                                      .map(
                                        (b) => '${b.amount}${b.currencyCode}',
                                      )
                                      .toList(),
                                );
                          },
                          builder: (context, state) {
                            final userSummary = state.userSummary;
                            final balances = userSummary?.displayBalances ?? [];
                            final balanceTextStyle =
                                balances.length > 1
                                    ? theme.textTheme.displaySmall
                                    : theme.textTheme.displayMedium;
                            return Column(
                              children:
                                  balances
                                      .map(
                                        (b) => BBText(
                                          '${b.amount} ${b.currencyCode}',
                                          style: balanceTextStyle?.copyWith(
                                            color: theme.colorScheme.onPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      )
                                      .toList(),
                            );
                          },
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
