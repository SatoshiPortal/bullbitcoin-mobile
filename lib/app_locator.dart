import 'package:bb_mobile/core/core_locator.dart';
import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/data/datasources/impl/bull_bitcoin_exchange_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bb_mobile/core/domain/usecases/get_default_wallets_metadata_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallet_balance_sat_usecase.dart';
import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_locator.dart';
import 'package:bb_mobile/features/fiat_currencies/fiat_currencies_locator.dart';
import 'package:bb_mobile/features/home/home_locator.dart';
import 'package:bb_mobile/features/language/language_locator.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:bb_mobile/features/pin_code/pin_code_locator.dart';
import 'package:bb_mobile/features/receive/receive_locator.dart';
import 'package:bb_mobile/features/recover_wallet/recover_wallet_locator.dart';
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

class AppLocator {
  /// Call this in the `main` function **before** `runApp()`
  static Future<void> setup() async {
    locator.enableRegisteringMultipleInstancesOfOneType();

    // Register core dependencies first
    await CoreLocator.setup();

    // Register feature-specific dependencies
    AppStartupLocator.setup();
    OnboardingLocator.setup();
    RecoverWalletLocator.setup();
    FiatCurrenciesLocator.setup();
    HomeLocator.setup();
    PinCodeLocator.setup();
    AppUnlockLocator.setup();
    LanguageLocator.setup();
    ReceiveLocator.setup();
  }
}
