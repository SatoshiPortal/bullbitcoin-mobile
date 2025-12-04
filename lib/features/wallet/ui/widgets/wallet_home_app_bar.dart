import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletHomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final showChart = context.select(
      (PriceChartCubit cubit) => cubit.state.showChart,
    );

    final currency = context.select(
      (PriceChartCubit cubit) => cubit.state.currency ?? 'CAD',
    );

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: showChart
          ? null
          : const TopBarBullLogo(enableSuperuserTapUnlocker: true),
      leading: showChart
          ? Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: context.appColors.onPrimary,
                  size: 24,
                ),
                onPressed: () {
                  context.read<PriceChartCubit>().hideChart();
                },
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: IconButton(
                icon: Icon(
                  Icons.show_chart,
                  color: context.appColors.onPrimary,
                  size: 24,
                ),
                onPressed: () {
                  context.read<PriceChartCubit>().showChart(currency);
                },
              ),
            ),
      leadingWidth: 56,
      actionsIconTheme: IconThemeData(
        color: context.appColors.onPrimary,
        size: 24,
      ),
      actionsPadding: const EdgeInsets.only(right: 16),
      actions: showChart
          ? null
          : [
              IconButton(
                onPressed: () {
                  context.pushNamed(TransactionsRoute.transactions.name);
                },
                visualDensity: VisualDensity.compact,
                color: context.appColors.onPrimary,
                iconSize: 32,
                icon: const Icon(Icons.history),
              ),
              const Gap(16),
              InkWell(
                onTap: () => context.pushNamed(SettingsRoute.settings.name),
                child: Image.asset(
                  Assets.icons.settingsLine.path,
                  width: 32,
                  height: 32,
                  color: context.appColors.onPrimary,
                ),
              ),
            ],
    );
  }
}
