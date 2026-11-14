import 'dart:async';

import 'package:bb_mobile/app.dart';
import 'package:bb_mobile/core/screens/app_init_error_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/support/public/support_facade.dart';
import 'package:bb_mobile/init.dart';
import 'package:bb_mobile/startup_wizard.dart';
import 'package:bull_local_data/bull_local_data.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ui/bull_ui.dart' show BullSupportScope;
import 'package:flutter/material.dart';
import 'package:primitives/primitives.dart';

Future<void> startApp() async {
  await runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        await runStartupWizard();
        await Bull.init();
      } catch (error, stackTrace) {
        await _showInitError(error, stackTrace);
        return;
      }
      await _openLocalDataAndStart();
    },
    (error, stackTrace) {
      // Use try-catch to prevent cascading crashes if logging itself fails
      try {
        log.severe(
          message: 'Global Unhandled Error',
          error: error,
          trace: stackTrace,
        );
      } catch (_) {
        debugPrint(
          'Global Unhandled Error (logger failed): $error\n$stackTrace',
        );
      } finally {
        // Best-effort: push the just-queued severe write to disk before
        // a potential subsequent crash takes the isolate down. The
        // handler signature is synchronous so we can't await here;
        // `_queueWrite` is itself `unawaited` for SEVERE flushes which
        // means this scheduled flush is still racy at process death.
        // Sentry preserves the event independently via `Report.error`.
        unawaited(log.flush());
      }
    },
  );
}

/// Opens the local databases, then starts the app on them. Runs again from the local data screen's retry, after an unlock or a reset.
Future<void> _openLocalDataAndStart() async {
  final LocalDatabasePaths paths;
  final LocalDataSession session;
  try {
    paths = await Bull.localDatabasePaths();
    switch (await Bull.openLocalData(paths)) {
      case Ok(:final value):
        session = value;
      case Err(:final failure) when LocalData.hasScreenFor(failure):
        log.warning('Local data unavailable at startup: $failure');
        await log.flush();
        runApp(_localDataApp(failure, paths));
        return;
      case Err(:final failure):
        await _showInitError(failure, StackTrace.current);
        return;
    }
  } catch (error, stackTrace) {
    await _showInitError(error, stackTrace);
    return;
  }

  try {
    await Bull.start(session, paths);
  } catch (error, stackTrace) {
    // The session owns the main database: nothing may hold it open behind an error screen.
    await session.close();
    await _showInitError(error, stackTrace);
    return;
  }
  await log.flush();
  runApp(const BullBitcoinWalletApp());
  _refreshDiagnosticContextAfterFirstFrame();
}

Widget _localDataApp(LocalDataFailure failure, LocalDatabasePaths paths) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(AppThemeType.dark),
      localizationsDelegates: LocalDataLocalizations.localizationsDelegates,
      supportedLocales: LocalDataLocalizations.supportedLocales,
      home: BullSupportScope(
        onContactSupport: SupportFacade.contactSupport,
        child: LocalData.screen(
          failure: failure,
          secrets: Bull.secrets,
          paths: paths,
          onRetry: _openLocalDataAndStart,
        ),
      ),
    );

Future<void> _showInitError(Object error, StackTrace stackTrace) async {
  log.severe(message: 'App Init Error', error: error, trace: stackTrace);
  // Make sure the just-logged severe line is on disk before we
  // render AppInitErrorScreen — the user typically shares logs
  // from that screen to support, and the buffered severe write
  // would otherwise still be pending in the IOSink.
  await log.flush();
  runApp(
    BullSupportScope(
      onContactSupport: SupportFacade.contactSupport,
      child: AppInitErrorScreen(error: error),
    ),
  );
  _refreshDiagnosticContextAfterFirstFrame();
}

void _refreshDiagnosticContextAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(log.refreshDiagnosticContext());
  });
}
