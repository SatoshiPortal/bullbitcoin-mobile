import 'package:electrum/electrum.dart' show ElectrumFailure;
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/app_startup/public/app_startup_facade.dart';

import 'dart:async';

import 'package:bull_recoverbull/bull_recoverbull.dart';

import 'package:bb_mobile/features/wallet/public/ark_foreground_setup.dart';
import 'package:bb_mobile/background_setup.dart';
import 'package:bb_mobile/background_entrypoint.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bull_reporting/bull_reporting.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_settings_facade.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_libraries.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show payjoinDatabaseFilename;
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:btc_map/btc_map.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Bull {
  static Future<Result<void, ElectrumFailure>> init() async {
    final bullDirectory = await getApplicationDocumentsDirectory();
    final payjoinDatabasePath = p.join(
      bullDirectory.path,
      payjoinDatabaseFilename,
    );

    await initializeLogging(
      directory: bullDirectory,
      reporter: const ReportLoggerAdapter(),
    );
    // The pre-init wizard writes consent to prefs via the bloc's
    // `SavePendingWizardChoicesUsecase` right before this runs. Pull
    // it so Sentry initializes with the user's freshest answer rather
    // than a stale mirror, and so migration errors that happen on this
    // very boot are captured if the user just opted in.
    await Report.init(
      dsn: ApiServiceConstants.sentryDsn,
      wizardConsent: await readStartupReportingConsent(),
    );

    await initFlutterRustBridgeDependencies();

    // Foreground only: background tasks never read a price, and must not open
    // the pricer's database while the app may be upgrading it.
    await Pricer.init(
      databasePath: p.join(bullDirectory.path, 'pricer.sqlite'),
    );

    await BtcMapFeature.initialize();

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    final setup = await AppLocator.setup(
      locator,
      SqliteDatabase(),
      payjoinDatabasePath: payjoinDatabasePath,
      arkFundingDatabasePath: p.join(bullDirectory.path, 'ark-funding.sqlite'),
      initializeArkFunding: _arkProfileAdmitted && _arkInitializeNew,
    );
    if (setup case Err()) return setup;
    await initializeWalletRuntime(locator);
    // Custody inventory is already installed, independently of this profile.
    await _setupArkRegtestProfile();
    Bloc.observer = AppBlocObserver();

    // Flush wizard pending values (if any) to SQLite now that the
    // settings repository is available, then mark the wizard complete.
    final _ = await locator<ExchangeFacade>().resolveAccess();
    await completeStartupWizard(locator);
    await locator<QuickActionsCubit>().load();
    await AppLocator.setupRecoverBull(
      locator,
      databasePath: p.join(bullDirectory.path, 'recoverbull.sqlite'),
    );
    unawaited(locator<RecoverBullFacade>().checkAtColdStart());
    final settings = locator<SettingsRepository>();
    configureLogTorContext(
      () => loadTorDiagnosticContext(settings, locator<Tor>()),
    );
    await refreshReportingConsent(settings);
    await prepareBackgroundWalletStores(locator);
    await configureBackgroundTasks();

    await Report.recordMigration();
    return const Ok(null);
  }
}

/// Explicit regtest Ark profile supplied at build time. Builds without both
/// endpoints keep the unavailable Ark routes; existing custody is still read.
/// BULL_ARK_REGTEST_INITIALIZE_NEW authorizes creating the account registry
/// and funding authority of a fresh, controlled regtest profile; it is never
/// inferred from files.
const _arkUrl = String.fromEnvironment('BULL_ARK_REGTEST_URL');
const _arkEsploraUrl = String.fromEnvironment('BULL_ARK_REGTEST_ESPLORA_URL');
const _arkInitializeNew = bool.fromEnvironment(
  'BULL_ARK_REGTEST_INITIALIZE_NEW',
);
const _arkProfileAdmitted = _arkUrl != '' && _arkEsploraUrl != '';

Future<void> _setupArkRegtestProfile() async {
  final arkUrl = Uri.tryParse(_arkUrl);
  final esploraUrl = Uri.tryParse(_arkEsploraUrl);
  if (!_arkProfileAdmitted || arkUrl == null || esploraUrl == null) return;
  await setupArkForeground(
    locator,
    arkUrl: arkUrl,
    primaryEsploraUrl: esploraUrl,
    initializeNew: _arkInitializeNew,
    dispatcher: backgroundTasksHandler,
  );
}
