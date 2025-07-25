import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/coming_soon_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sliver_tools/sliver_tools.dart';

class ExchangeHomeScreen extends StatelessWidget {
  const ExchangeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isFetchingUserSummary = context.select(
      (ExchangeCubit cubit) => cubit.state.isFetchingUserSummary,
    );
    final notLoggedIn = context.select(
      (ExchangeCubit cubit) => cubit.state.notLoggedIn,
    );
    final isFullyVerified = context.select(
      (ExchangeCubit cubit) => cubit.state.isFullyVerifiedKycLevel,
    );

    if (isFetchingUserSummary || notLoggedIn) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      edgeOffset: 30,
      onRefresh: () async {
        await context.read<ExchangeCubit>().fetchUserSummary();
      },
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverStack(
                children: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const ExchangeHomeTopSection(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            const Gap(12),
                            if (!isFullyVerified) const ExchangeHomeKycCard(),
                            const Gap(12),
                            /*
                        SwitchListTile(
                          value: false,
                          onChanged: (value) {},
                          title: const Text('Activate auto-buy'),
                        ),
                        const Gap(12),
                        SwitchListTile(
                          value: false,
                          onChanged: (value) {},
                          title: const Text('Activate recurring buy'),
                        ),
                        const Gap(12),
                        ListTile(
                          title: const Text('View auto-sell address'),
                          onTap: () {},
                          trailing: const Icon(Icons.arrow_forward),
                        ),
                        const Gap(12),
                        */
                          ],
                        ),
                      ), // Bottom-aligned button
                    ]),
                  ),
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    floating: true,
                    pinned: true,
                    elevation: 0,
                    centerTitle: true,
                    title: const TopBarBullLogo(),
                    actionsIconTheme: IconThemeData(
                      color: context.colour.onPrimary,
                      size: 24,
                    ),
                    actionsPadding: const EdgeInsets.only(right: 16),
                    actions: [
                      IconButton(
                        padding: const EdgeInsets.only(right: 16),
                        onPressed: () {
                          context.pushNamed(
                            TransactionsRoute.transactions.name,
                          );
                        },
                        visualDensity: VisualDensity.compact,
                        color: context.colour.onPrimary,
                        iconSize: 24,
                        icon: const Icon(Icons.history),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: InkWell(
                          onTap:
                              () => context.pushNamed(
                                SettingsRoute.settings.name,
                              ),
                          child: Image.asset(
                            Assets.icons.settingsLine.path,
                            width: 24,
                            height: 24,
                            color: context.colour.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: BBButton.big(
                        iconData: Icons.arrow_downward,
                        label: 'Deposit',
                        iconFirst: true,
                        onPressed:
                            () => context.pushNamed(
                              FundExchangeRoute.fundExchangeAccount.name,
                            ),
                        bgColor: context.colour.secondary,
                        textColor: context.colour.onPrimary,
                      ),
                    ),
                    const Gap(4),
                    Expanded(
                      child: BBButton.big(
                        iconData: Icons.arrow_upward,
                        label: 'Withdraw',
                        iconFirst: true,
                        disabled: false,
                        onPressed: () {
                          ComingSoonBottomSheet.show(
                            context,
                            description:
                                'Withdraw Fiat from Account Balance to External Account',
                          );
                        },
                        bgColor: context.colour.secondary,
                        textColor: context.colour.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
