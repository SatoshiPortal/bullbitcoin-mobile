import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/logout_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/not_logged_in_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeSettingsScreen extends StatelessWidget {
  const ExchangeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((ExchangeCubit cubit) => cubit.state);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsExchangeSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.account_circle,
                  title: context.loc.exchangeSettingsAccountInformationTitle,
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(SettingsRoute.exchangeAccountInfo.name);
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.security,
                  title: context.loc.exchangeSettingsSecuritySettingsTitle,
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(SettingsRoute.exchangeSecurity.name);
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.people,
                  title: context.loc.exchangeSettingsRecipientsTitle,
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(PayRoute.pay.name);
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.history,
                  title: context.loc.exchangeSettingsTransactionsTitle,
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(
                        SettingsRoute.exchangeTransactions.name,
                      );
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.currency_bitcoin,
                  title: 'Default Bitcoin Wallets',
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(
                        SettingsRoute.exchangeBitcoinWallets.name,
                      );
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.settings,
                  title: 'App Settings',
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(SettingsRoute.exchangeAppSettings.name);
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.upload_file,
                  title: 'Secure File Upload',
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(SettingsRoute.exchangeFileUpload.name);
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.bar_chart,
                  title: 'Statistics',
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(SettingsRoute.exchangeStatistics.name);
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.share,
                  title: context.loc.exchangeSettingsReferralsTitle,
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(SettingsRoute.exchangeReferrals.name);
                    }
                  },
                ),
                if (state.notLoggedIn)
                  SettingsEntryItem(
                    icon: Icons.login,
                    title: context.loc.exchangeSettingsLogInTitle,
                    onTap: () {
                      context.goNamed(ExchangeRoute.exchangeLanding.name);
                    },
                  ),
                if (!state.notLoggedIn)
                  SettingsEntryItem(
                    icon: Icons.logout,
                    title: context.loc.exchangeSettingsLogOutTitle,
                    onTap: () {
                      if (state.notLoggedIn) {
                        NotLoggedInBottomSheet.show(context);
                      } else {
                        LogoutConfirmationBottomSheet.show(
                          context,
                          onConfirm: () async {
                            await context.read<ExchangeCubit>().logout();
                          },
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
