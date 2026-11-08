import 'dart:async';

import 'package:bb_mobile/app.dart';
import 'package:bb_mobile/core/screens/app_init_error_screen.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/init.dart';
import 'package:bb_mobile/startup_wizard.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/material.dart';

Future<void> startApp() async {
  await runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        // Android initializes FSS10 lazily and may spend several seconds in a
        // cold fsync. When no supported prior-install marker exists, start that
        // local-only work during the wizard. Upgrade probes stay in Bull.init.
        unawaited(StorageLocator.prewarmSecureStorage());
        await runStartupWizard();
        await Bull.init();
      } catch (error, stackTrace) {
        log.severe(message: 'App Init Error', error: error, trace: stackTrace);
        runApp(AppInitErrorScreen(error: error));
        _refreshDiagnosticContextAfterFirstFrame();
        return;
      } finally {
        // Make sure the just-logged severe line is on disk before we
        // render AppInitErrorScreen — the user typically shares logs
        // from that screen to support, and the buffered severe write
        // would otherwise still be pending in the IOSink.
        await log.flush();
      }
      runApp(const BullBitcoinWalletApp());
      _refreshDiagnosticContextAfterFirstFrame();
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

void _refreshDiagnosticContextAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(log.refreshDiagnosticContext());
  });
}
