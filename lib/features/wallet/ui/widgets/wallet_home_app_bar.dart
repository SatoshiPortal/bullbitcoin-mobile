import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/price_chart_bloc.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/service_status_indicator.dart';
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
      (PriceChartBloc bloc) => bloc.state.rateHistory != null,
    );

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title:
          showChart
              ? null
              : const TopBarBullLogo(enableSuperuserTapUnlocker: true),
      leading:
          showChart
              ? Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: context.colour.onPrimary,
                    size: 24,
                  ),
                  onPressed: () {
                    context.read<PriceChartBloc>().add(
                      const PriceChartEvent.closed(),
                    );
                  },
                ),
              )
              : const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: ServiceStatusIndicator(),
              ),
      leadingWidth: showChart ? 56 : 48,
      actionsIconTheme: IconThemeData(
        color: context.colour.onPrimary,
        size: 24,
      ),
      actionsPadding: const EdgeInsets.only(right: 16),
      actions:
          showChart
              ? null
              : [
                IconButton(
                  onPressed: () {
                    context.pushNamed(TransactionsRoute.transactions.name);
                  },
                  visualDensity: VisualDensity.compact,
                  color: context.colour.onPrimary,
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
                    color: context.colour.onPrimary,
                  ),
                ),
              ],
    );
  }
}
