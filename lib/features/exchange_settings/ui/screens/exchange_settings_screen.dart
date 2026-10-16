import 'dart:io';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/not_logged_in_bottom_sheet.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/ui/exchange_settings_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeSettingsScreen extends StatelessWidget {
  const ExchangeSettingsScreen({
    required this.isSuperuser,
    required this.onOpenRecipients,
    required this.onOpenTransactions,
    required this.onOpenDefaultWallets,
    super.key,
  });

  final bool isSuperuser;
  final VoidCallback onOpenRecipients;
  final VoidCallback onOpenTransactions;
  final VoidCallback onOpenDefaultWallets;

  @override
  Widget build(BuildContext context) {
    return ExchangeSessionBuilder(
      builder: (context, isLoggedIn) {
        void openWhenLoggedIn(VoidCallback open) {
          if (isLoggedIn) {
            open();
          } else {
            NotLoggedInBottomSheet.show(context);
          }
        }

        void pushWhenLoggedIn(ExchangeSettingsRoute route) =>
            openWhenLoggedIn(() => context.pushNamed(route.name));

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isSuperuser
                  ? context.loc.settingsExchangeSettingsTitle
                  : context.loc.settingsAccountSettingsTitle,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (isSuperuser || Platform.isAndroid) ...[
                      BullSettingsEntryItem(
                        icon: Icons.account_circle,
                        title:
                            context.loc.exchangeSettingsAccountInformationTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.accountInfo),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.security,
                        title:
                            context.loc.exchangeSettingsSecuritySettingsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.security),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.people,
                        title: context.loc.exchangeSettingsRecipientsTitle,
                        onTap: () => openWhenLoggedIn(onOpenRecipients),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.history,
                        title: context.loc.exchangeSettingsTransactionsTitle,
                        onTap: () => openWhenLoggedIn(onOpenTransactions),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.currency_bitcoin,
                        title: context.loc.exchangeBitcoinWalletsTitle,
                        onTap: () => openWhenLoggedIn(onOpenDefaultWallets),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.settings,
                        title: context.loc.settingsAppSettingsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.preferences),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.upload_file,
                        title: context.loc.exchangeFileUploadTitle,
                        onTap: () => pushWhenLoggedIn(
                          ExchangeSettingsRoute.secureFileUpload,
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.bar_chart,
                        title: context.loc.exchangeStatisticsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.statistics),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.share,
                        title: context.loc.exchangeSettingsReferralsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.referrals),
                      ),
                      if (!isLoggedIn)
                        BullSettingsEntryItem(
                          icon: Icons.login,
                          title: context.loc.exchangeSettingsLogInTitle,
                          onTap: () => context.goNamed(
                            ExchangeRoute.exchangeLanding.name,
                          ),
                        ),
                    ],
                    ExchangeAccountActions(
                      showDeleteAccount: !isSuperuser && Platform.isIOS,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
