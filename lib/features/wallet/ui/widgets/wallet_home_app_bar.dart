import 'dart:io';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/exchange_support_chat_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletHomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  const WalletHomeAppBar({super.key, this.isExchange = false});

  final bool isExchange;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<WalletHomeAppBar> createState() => _WalletHomeAppBarState();
}

class _WalletHomeAppBarState extends State<WalletHomeAppBar> {
  bool _hasTriggeredFetch = false;

  void _goToExchange() {
    if (Platform.isIOS) {
      final isSuperuser =
          context.read<SettingsCubit>().state.isSuperuser ?? false;
      if (isSuperuser) {
        context.goNamed(ExchangeRoute.exchangeHome.name);
      } else {
        context.goNamed(ExchangeRoute.exchangeLanding.name);
      }
    } else {
      context.goNamed(ExchangeRoute.exchangeHome.name);
    }
  }

  void _goToWallet() {
    context.goNamed(WalletRoute.walletHome.name);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasTriggeredFetch) {
      _hasTriggeredFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cubit = context.read<ExchangeCubit>();
        if (cubit.state.userSummary == null &&
            cubit.state.apiKeyException == null) {
          cubit.fetchUserSummary();
        }
      });
    }
    final showChart = context.select(
      (PriceChartCubit cubit) => cubit.state.showChart,
    );

    final iconColor = context.appColors.textMuted;
    final isExchange = widget.isExchange;

    return AppBar(
      backgroundColor: context.appColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: const TopBarBullLogo(enableSuperuserTapUnlocker: true),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: showChart
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: iconColor, size: 24),
                onPressed: () {
                  context.read<PriceChartCubit>().hideChart();
                },
              )
            : SizedBox(
                width: 96,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.show_chart, color: iconColor, size: 24),
                      onPressed: () {
                        context.read<PriceChartCubit>().showChart();
                      },
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        color: iconColor,
                        size: 24,
                      ),
                      onPressed: () {
                        final notLoggedIn = context
                            .read<ExchangeCubit>()
                            .state
                            .notLoggedIn;
                        if (notLoggedIn) {
                          context.pushNamed(
                            ExchangeRoute.exchangeLoginForSupport.name,
                          );
                        } else {
                          context.pushNamed(
                            ExchangeSupportChatRoute.supportChat.name,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
      ),
      leadingWidth: showChart ? 56 : 112,
      actionsIconTheme: IconThemeData(color: iconColor, size: 24),
      actionsPadding: const EdgeInsets.only(right: 16),
      actions: showChart
          ? null
          : [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isExchange
                      ? Icons.account_balance_wallet_outlined
                      : Icons.attach_money,
                  color: iconColor,
                  size: 24,
                ),
                onPressed: isExchange ? _goToWallet : _goToExchange,
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => context.pushNamed(SettingsRoute.settings.name),
                child: Image.asset(
                  Assets.icons.settingsLine.path,
                  width: 24,
                  height: 24,
                  color: iconColor,
                ),
              ),
            ],
    );
  }
}
