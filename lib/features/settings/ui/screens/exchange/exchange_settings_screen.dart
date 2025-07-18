import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/ui/components/settings/settings_entry_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeSettingsScreen extends StatelessWidget {
  const ExchangeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    context.pushNamed(SettingsRoute.exchangeAccountInfo.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.security,
                  title: 'Security Settings',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeSecurity.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.currency_bitcoin,
                  title: 'Default Bitcoin Wallets',
                  onTap: () {
                    context.pushNamed(
                      SettingsRoute.exchangeBitcoinWallets.name,
                    );
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.settings,
                  title: 'App Settings',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeAppSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.upload_file,
                  title: 'Secure File Upload',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeFileUpload.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.history,
                  title: 'Transactions',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeTransactions.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.history_edu,
                  title: 'Legacy Transactions',
                  onTap: () {
                    context.pushNamed(
                      SettingsRoute.exchangeLegacyTransactions.name,
                    );
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.people,
                  title: 'Recipients',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeRecipients.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.share,
                  title: 'Referrals',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeReferrals.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.logout,
                  title: 'Log Out',
                  onTap: () {
                    context.pushNamed(SettingsRoute.exchangeLogout.name);
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
