import 'package:bb_mobile/core/core_locator.dart';
import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_locator.dart';
import 'package:bb_mobile/features/bitcoin_price/bitcoin_price_locator.dart';
import 'package:bb_mobile/features/home/home_locator.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_wallet_locator.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:bb_mobile/features/pin_code/pin_code_locator.dart';
import 'package:bb_mobile/features/receive/receive_locator.dart';
import 'package:bb_mobile/features/recover_wallet/recover_wallet_locator.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

class AppLocator {
  /// Call this in the `main` function **before** `runApp()`
  static Future<void> setup() async {
    locator.enableRegisteringMultipleInstancesOfOneType();

    // Register core dependencies first
    await CoreLocator.setup();

    // Register feature-specific dependencies
    PinCodeLocator.setup();
    AppStartupLocator.setup();
    AppUnlockLocator.setup();
    OnboardingLocator.setup();
    RecoverWalletLocator.setup();
    SettingsLocator.setup();
    BitcoinPriceLocator.setup();
    HomeLocator.setup();
    ReceiveLocator.setup();
    ImportWatchOnlyWalletLocator.setup();
  }
}
