import 'dart:io';
import 'dart:async';
import 'package:bull_recoverbull/bull_recoverbull.dart';

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/report.dart';
import 'package:bb_mobile/tor_diagnostic_context.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_libraries.dart';
import 'package:bb_mobile/payjoin_setup.dart' show payjoinDatabaseFilename;
import 'package:bb_mobile/report_logger_adapter.dart';
import 'package:bb_mobile/startup_wizard.dart';
import 'package:bull_local_data/bull_local_data.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:secrets/secrets.dart';

class Bull {
  /// One per foreground run: the local databases' keys are read through it before the locator exists, and the locator then registers this same instance.
  ///
  /// Liquid signing removes its temporary children after use. Stale caches contain blinding material, so keep them in the OS's non-backed-up cache.
  static final secrets = Secrets(
    scratchDirectory: () async => (await getTemporaryDirectory()).path,
  );

  /// Logging, error reporting and native libraries: everything that runs before the local databases are opened.
  static Future<void> init() async {
    final bullDirectory = await getApplicationDocumentsDirectory();

    await initializeLogging(
      directory: bullDirectory,
      reporter: const ReportLoggerAdapter(),
      diagnosticContextSource: PlatformDiagnosticContextSource(
        runtime: _diagnosticRuntime,
      ),
    );
    // The pre-init wizard writes consent to prefs via the bloc's
    // `SavePendingWizardChoicesUsecase` right before this runs. Pull
    // it so Sentry initializes with the user's freshest answer rather
    // than a stale mirror, and so migration errors that happen on this
    // very boot are captured if the user just opted in.
    await Report.init(wizardConsent: await readStartupReportingConsent());

    await initFlutterRustBridgeDependencies();
  }

  /// Where the local databases live: each owner's file in the Documents directory, which iOS excludes from backups (AppDelegate).
  static Future<LocalDatabasePaths> localDatabasePaths() async {
    final bullDirectory = await getApplicationDocumentsDirectory();
    return LocalDatabasePaths(
      main: p.join(bullDirectory.path, '${SqliteDatabase.name}.sqlite'),
      payjoin: p.join(bullDirectory.path, payjoinDatabaseFilename),
      recoverbull: p.join(bullDirectory.path, 'recoverbull.sqlite'),
    );
  }

  /// Opens the local databases encrypted, encrypting them first if an earlier release left them in clear. Foreground only.
  static Future<Result<LocalDataSession, LocalDataFailure>> openLocalData(
    LocalDatabasePaths paths,
  ) => LocalData.unlock(secrets: secrets, paths: paths);

  /// Everything that needs the local databases open.
  static Future<void> start(
    LocalDataSession session,
    LocalDatabasePaths paths,
  ) async {
    final bullDirectory = await getApplicationDocumentsDirectory();

    // Foreground only: background tasks never read a price, and must not open
    // the pricer's database while the app may be upgrading it.
    await Pricer.init(
      databasePath: p.join(bullDirectory.path, 'pricer.sqlite'),
    );

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await AppLocator.setup(
      locator,
      SqliteDatabase(session.mainDatabase),
      secrets: secrets,
      payjoinDatabasePath: paths.payjoin,
      payjoinDatabaseKey: session.payjoinKey,
    );
    Bloc.observer = AppBlocObserver();

    // Flush wizard pending values (if any) to SQLite now that the
    // settings repository is available, then mark the wizard complete.
    await locator<ApplyPendingWizardChoicesUsecase>().execute();
    final recoverbull = await AppLocator.setupRecoverBull(
      locator,
      databasePath: paths.recoverbull,
      databaseKey: session.recoverbullKey,
    );
    try {
      final settings = locator<SettingsRepository>();
      configureLogTorContext(
        () => loadTorDiagnosticContext(settings, locator<Tor>()),
      );
      Report.consent = (await settings.fetch()).isErrorReportingEnabled;
      if (Platform.isAndroid || Platform.isIOS) {
        await cancelLegacyBackgroundTasks();
      }

      // Emits the install/upgrade transition event (no-op on a normal
      // launch) and advances the persisted version marker. The shout is
      // awaited so a crash between scheduling and capture cannot lose
      // the milestone — the persisted marker only advances once Sentry
      // has the event.
      final type = Report.migrationType;
      if (type != null) {
        await log.shout(message: type.name, category: ReportCategory.migration);
        await Report.commitVersion();
      }
    } catch (_) {
      await recoverbull.dispose();
      rethrow;
    }
    unawaited(recoverbull.facade.checkAtColdStart());
  }
}

final _diagnosticRuntime = DiagnosticRuntimeContext();

void configureLogTorContext(Future<DiagnosticTorContext> Function() loader) {
  _diagnosticRuntime.setTorLoader(loader);
}
