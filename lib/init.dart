import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/report.dart';
import 'package:bb_mobile/tor_diagnostic_context.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/startup_wizard.dart';
import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class Bull {
  static Future<void> init({String? payjoinDatabasePath}) async {
    await initLogs();
    // The pre-init wizard writes consent to prefs via the bloc's
    // `SavePendingWizardChoicesUsecase` right before this runs. Pull
    // it so Sentry initializes with the user's freshest answer rather
    // than a stale mirror, and so migration errors that happen on this
    // very boot are captured if the user just opted in.
    await Report.init(wizardConsent: await readStartupReportingConsent());

    await initFlutterRustBridgeDependencies();

    // The Locator setup might depend on the initialization of the libraries above
    //  so it's important to call it after the initialization
    await AppLocator.setup(
      locator,
      SqliteDatabase(),
      payjoinDatabasePath: payjoinDatabasePath,
    );
    Bloc.observer = AppBlocObserver();

    // Flush wizard pending values (if any) to SQLite now that the
    // settings repository is available, then mark the wizard complete.
    await locator<ApplyPendingWizardChoicesUsecase>().execute();
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
  }

  static Future<void> initFlutterRustBridgeDependencies() async {
    final initTasks = [
      BullSdk.init(),
      if (Platform.isAndroid) BitBoxApi.initialize(),
    ];

    await Future.wait(initTasks);
  }

  /// Uses separate files for foreground and background isolates to avoid concurrent writes to the same log.
  static Future<void> initLogs({bool background = false}) async {
    final logDirectory = await getApplicationDocumentsDirectory();
    final diagnosticContextProvider = background
        ? null
        : DiagnosticContextProvider(
            PlatformDiagnosticContextSource(runtime: _diagnosticRuntime),
          );
    log = Logger.replace(
      directory: logDirectory,
      background: background,
      diagnosticContextLoader: diagnosticContextProvider?.load,
      reporter: const _ReportLoggerReporter(),
    );
    // Create files now; bootstrap collects platform diagnostics after the first frame.
    await log.ensureLogsExist(writeDiagnosticContext: false);
    if (!background) {
      // Pruning is per isolate; only prune the foreground file here.
      unawaited(log.prune());
    }
  }
}

final _diagnosticRuntime = DiagnosticRuntimeContext();

void configureLogTorContext(Future<DiagnosticTorContext> Function() loader) {
  _diagnosticRuntime.setTorLoader(loader);
}

final class _ReportLoggerReporter implements LoggerReporter {
  const _ReportLoggerReporter();

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) {
    Report.error(
      message: message,
      exception: exception,
      stackTrace: stackTrace,
      category: category,
    );
  }

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) => Report.shout(
    message: message,
    exception: exception,
    stackTrace: stackTrace,
    category: category,
  );
}
