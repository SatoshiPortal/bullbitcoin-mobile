import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ExchangeHomeScreen extends StatelessWidget {
  const ExchangeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isFetchingUserSummary = context.select(
      (ExchangeCubit cubit) => cubit.state.isFetchingUserSummary,
    );
    final isApiKeyInvalid = context.select(
      (ExchangeCubit cubit) => cubit.state.isApiKeyInvalid,
    );
    final isFullyVerified = context.select(
      (ExchangeCubit cubit) => cubit.state.isFullyVerifiedKycLevel,
    );

    if (isFetchingUserSummary || isApiKeyInvalid) {
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
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final webviewController = WebViewController();
                          final cookieManager = WebviewCookieManager();
                          await Future.wait([
                            webviewController.clearCache(),
                            webviewController.clearLocalStorage(),
                            cookieManager.clearCookies(),
                            context.read<ExchangeCubit>().logout(),
                          ]);
                        },
                        iconSize: 24,
                        color: context.colour.onPrimary,
                        icon: const Icon(Icons.logout),
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
                        disabled: true,
                        onPressed: () {},
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
