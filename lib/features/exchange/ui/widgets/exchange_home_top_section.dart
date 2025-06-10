import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/cards/action_card.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ExchangeHomeTopSection extends StatelessWidget {
  const ExchangeHomeTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final defaultCurrency = context.select(
      (SettingsCubit settings) => settings.state.currencyCode,
    );
    final balances = context.select(
      (ExchangeCubit cubit) =>
          cubit.state.userSummary?.balances ??
          (defaultCurrency != null
              ? [UserBalance(amount: 0, currencyCode: defaultCurrency)]
              : []),
    );
    final balanceTextStyle =
        balances.length > 1
            ? theme.textTheme.displaySmall
            : theme.textTheme.displayMedium;
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
                    ),
                    const Positioned(
                      top: 54,
                      left: 0,
                      right: 0,
                      child: _TopNav(),
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

class _TopNav extends StatelessWidget {
  const _TopNav();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Gap(142),
        const Spacer(),
        TopBarBullLogo(
          onTap: () {
            context.read<ExchangeCubit>().fetchUserSummary();
          },
          enableSuperuserTapUnlocker: true,
        ),
        const Spacer(),
        IconButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            context.pushNamed(TransactionsRoute.transactions.name);
          },
          visualDensity: VisualDensity.compact,
          color: context.colour.onPrimary,
          iconSize: 24,
          icon: const Icon(Icons.history),
        ),
        const Gap(8),
        InkWell(
          onTap: () => context.pushNamed(SettingsRoute.settings.name),
          child: Image.asset(
            Assets.icons.settingsLine.path,
            width: 24,
            height: 24,
            color: context.colour.onPrimary,
          ),
        ),
        const Gap(8),
        IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            context.read<ExchangeCubit>().logout();
          },
          iconSize: 24,
          color: context.colour.onPrimary,
          icon: const Icon(Icons.logout),
        ),
        const Gap(16),
      ],
    );
  }
}
