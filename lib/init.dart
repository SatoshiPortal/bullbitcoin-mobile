import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/app_startup/public/app_startup_facade.dart';
import 'dart:async';
import 'package:bull_recoverbull/bull_recoverbull.dart';

import 'package:bb_mobile/background_setup.dart';
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
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Bull {
  static Future<void> init() async {
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

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await AppLocator.setup(
      locator,
      SqliteDatabase(),
      payjoinDatabasePath: payjoinDatabasePath,
    );
    await initializeWalletRuntime(locator);
    Bloc.observer = AppBlocObserver();

    // Flush wizard pending values (if any) to SQLite now that the
    // settings repository is available, then mark the wizard complete.
    await completeStartupWizard(locator);
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
  }
}
