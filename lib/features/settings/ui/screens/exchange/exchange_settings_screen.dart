import 'dart:io';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/delete_account_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/delete_account_success_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/logout_confirmation_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/not_logged_in_bottom_sheet.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeSettingsScreen extends StatelessWidget {
  const ExchangeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((ExchangeCubit cubit) => cubit.state);
    final isSuperuser =
        context.select((SettingsCubit cubit) => cubit.state.isSuperuser) ??
        false;

    return BullPage(
      topBar: BullTopBar(
        title: isSuperuser
            ? context.loc.settingsExchangeSettingsTitle
            : context.loc.settingsAccountSettingsTitle,
        onBack: context.pop,
      ),
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
      scrollable: true,
      child: Column(
        children: [
          if (isSuperuser || Platform.isAndroid) ...[
            BullSettingsEntryItem(
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
            BullSettingsEntryItem(
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
            BullSettingsEntryItem(
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
            BullSettingsEntryItem(
              icon: Icons.history,
              title: context.loc.exchangeSettingsTransactionsTitle,
              onTap: () {
                if (state.notLoggedIn) {
                  NotLoggedInBottomSheet.show(context);
                } else {
                  context.pushNamed(SettingsRoute.exchangeTransactions.name);
                }
              },
            ),
            BullSettingsEntryItem(
              icon: Icons.currency_bitcoin,
              title: context.loc.exchangeBitcoinWalletsTitle,
              onTap: () {
                if (state.notLoggedIn) {
                  NotLoggedInBottomSheet.show(context);
                } else {
                  context.pushNamed(SettingsRoute.exchangeBitcoinWallets.name);
                }
              },
            ),
            BullSettingsEntryItem(
              icon: Icons.settings,
              title: context.loc.settingsAppSettingsTitle,
              onTap: () {
                if (state.notLoggedIn) {
                  NotLoggedInBottomSheet.show(context);
                } else {
                  context.pushNamed(SettingsRoute.exchangeAppSettings.name);
                }
              },
            ),
            BullSettingsEntryItem(
              icon: Icons.upload_file,
              title: context.loc.exchangeFileUploadTitle,
              onTap: () {
                if (state.notLoggedIn) {
                  NotLoggedInBottomSheet.show(context);
                } else {
                  context.pushNamed(SettingsRoute.exchangeFileUpload.name);
                }
              },
            ),
            BullSettingsEntryItem(
              icon: Icons.bar_chart,
              title: context.loc.exchangeStatisticsTitle,
              onTap: () {
                if (state.notLoggedIn) {
                  NotLoggedInBottomSheet.show(context);
                } else {
                  context.pushNamed(SettingsRoute.exchangeStatistics.name);
                }
              },
            ),
            BullSettingsEntryItem(
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
              BullSettingsEntryItem(
                icon: Icons.login,
                title: context.loc.exchangeSettingsLogInTitle,
                onTap: () {
                  context.goNamed(ExchangeRoute.exchangeLanding.name);
                },
              ),
          ],
          if (!state.notLoggedIn && !isSuperuser && Platform.isIOS)
            BullSettingsEntryItem(
              icon: Icons.delete_forever,
              title: context.loc.exchangeSettingsDeleteAccountTitle,
              onTap: () {
                final cubit = context.read<ExchangeCubit>();
                DeleteAccountConfirmationBottomSheet.show(
                  context,
                  onConfirm: () async {
                    await cubit.deleteAccount();
                    if (context.mounted) {
                      await DeleteAccountSuccessBottomSheet.show(context);
                    }
                  },
                );
              },
            ),
          if (!state.notLoggedIn)
            BullSettingsEntryItem(
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
    );
  }
}
