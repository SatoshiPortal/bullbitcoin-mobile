import 'package:bb_mobile/core/widgets/logout_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/not_logged_in_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
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
      appBar: AppBar(title: const Text('Exchange Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.account_circle,
                  title: 'Account Information',
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
                  title: 'Security Settings',
                  onTap: () {
                    if (state.notLoggedIn) {
                      NotLoggedInBottomSheet.show(context);
                    } else {
                      context.pushNamed(SettingsRoute.exchangeSecurity.name);
                    }
                  },
                ),
                // SettingsEntryItem(
                //   icon: Icons.currency_bitcoin,
                //   title: 'Default Bitcoin Wallets',
                //   onTap: () {
                //     if (state.notLoggedIn) {
                //       NotLoggedInBottomSheet.show(context);
                //     } else {
                //       ComingSoonBottomSheet.show(context);
                //     }
                //   },
                // ),
                // SettingsEntryItem(
                //   icon: Icons.settings,
                //   title: 'App Settings',
                //   onTap: () {
                //     if (state.notLoggedIn) {
                //       NotLoggedInBottomSheet.show(context);
                //     } else {
                //       ComingSoonBottomSheet.show(context);
                //     }
                //   },
                // ),
                // SettingsEntryItem(
                //   icon: Icons.upload_file,
                //   title: 'Secure File Upload',
                //   onTap: () {
                //     if (state.notLoggedIn) {
                //       NotLoggedInBottomSheet.show(context);
                //     } else {
                //       ComingSoonBottomSheet.show(context);
                //     }
                //   },
                // ),
                // SettingsEntryItem(
                //   icon: Icons.history,
                //   title: 'Transactions',
                //   onTap: () {
                //     if (state.notLoggedIn) {
                //       NotLoggedInBottomSheet.show(context);
                //     } else {
                //       context.pushNamed(
                //         SettingsRoute.exchangeTransactions.name,
                //       );
                //     }
                //   },
                // ),
                // SettingsEntryItem(
                //   icon: Icons.history_edu,
                //   title: 'Legacy Transactions',
                //   onTap: () {
                //     if (state.notLoggedIn) {
                //       NotLoggedInBottomSheet.show(context);
                //     } else {
                //       context.pushNamed(
                //         SettingsRoute.exchangeLegacyTransactions.name,
                //       );
                //     }
                //   },
                // ),
                // SettingsEntryItem(
                //   icon: Icons.people,
                //   title: 'Recipients',
                //   onTap: () {
                //     if (state.notLoggedIn) {
                //       NotLoggedInBottomSheet.show(context);
                //     } else {
                //       context.pushNamed(SettingsRoute.exchangeRecipients.name);
                //     }
                //   },
                // ),
                SettingsEntryItem(
                  icon: Icons.share,
                  title: 'Referrals',
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
                    title: 'Log In',
                    onTap: () {
                      context.goNamed(ExchangeRoute.exchangeAuth.name);
                    },
                  ),
                if (!state.notLoggedIn)
                  SettingsEntryItem(
                    icon: Icons.logout,
                    title: 'Log Out',
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
