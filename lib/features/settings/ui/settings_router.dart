import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/features/backup_wallet/ui/backup_wallet_router.dart';
import 'package:bb_mobile/features/pin_code/ui/pin_code_setting_flow.dart';
import 'package:bb_mobile/features/settings/ui/screens/language_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/settings_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:go_router/go_router.dart';

enum SettingsRoute {
  settings('settings'),
  pinCode('pin-code'),
  language('language'),
  currency('currency'),
  backupSettings('backup-settings');

  final String path;

  const SettingsRoute(this.path);
}

class SettingsRouter {
  static final route = GoRoute(
    name: SettingsRoute.settings.name,
    path: SettingsRoute.settings.path,
    builder: (context, state) => const SettingsScreen(),
    routes: [
      GoRoute(
        name: SettingsRoute.language.name,
        path: SettingsRoute.language.path,
        builder: (context, state) => const LanguageSettingsScreen(),
      ),
      GoRoute(
        path: SettingsRoute.pinCode.path,
        name: SettingsRoute.pinCode.name,
        builder: (context, state) => const PinCodeSettingFlow(),
      ),
      GoRoute(
        path: SettingsRoute.backupSettings.path,
        name: SettingsRoute.backupSettings.name,
        builder: (context, state) => const BackupSettingsScreen(),
        routes: [
          ...BackupSettingsSettingsRouter.routes,
          ...BackupWalletRouter.routes,
          ...TestWalletBackupRouter.routes,
        ],
      ),

      /** TODO: Implement CurrencySettingsScreen
     * Add the `BitcoinPriceCurrencyChanged` event to the `BitcoinPriceBloc` when the currency is changed successfully on the settings screen
     *  This way the `BitcoinPriceBloc` can fetch the bitcoin price with the new currency and the whole app will be updated with the new currency
     * The global BitcoinPriceBloc can also be used to obtain the available fiat currencies and show them in the CurrencySettingsScreen
    GoRoute(
      path: SettingsRoute.currency.path,
      name: SettingsRoute.currency.name,
      builder: (context, state) => const CurrencySettingsScreen(),
    ),*/
    ],
  );
}
