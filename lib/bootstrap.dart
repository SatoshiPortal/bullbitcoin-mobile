import 'package:primitives/primitives.dart' show Err;

import 'dart:async';

import 'package:bb_mobile/app.dart';
import 'package:startup/startup.dart'
    show
        AppInitErrorScreen,
        InventoryRecoveryRequired,
        InventoryUnreadableScreen;
import 'package:settings/settings.dart';
import 'package:bb_mobile/init.dart';
import 'package:notifications/payment_store.dart' show PaymentNotifications;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ui/bull_ui.dart' show BullSupportScope;
import 'package:exchange/exchange.dart'
    show ExchangeAvailability, ExchangePlatform;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:legacy_storage/legacy_storage.dart' show LegacyImportFailure;
import 'package:material_ui/material_ui.dart';
import 'package:wizard/wizard.dart';

Future<void> startApp() async {
  await runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        final wizard = WizardFeature.mount();
        final startup = await wizard.runIfNeeded(
          notificationChannelId: PaymentNotifications.channelId,
          branding: WizardBranding(
            headerLogo: AssetImage(Assets.logos.bbLogoSmall.path),
            welcomeLogo: AssetImage(Assets.logos.bbLogoWhite.path),
            welcomePattern: AssetImage(Assets.backgrounds.bgLong.path),
          ),
          exchangeAllowed: ExchangeAvailability.platformAllowed(
            defaultTargetPlatform == TargetPlatform.iOS
                ? ExchangePlatform.ios
                : ExchangePlatform.other,
          ),
        );
        if (startup case Err(:final failure)) {
          _showInitError(failure);
          return;
        }
        if (await Bull.init(
              retryStorage: _retryStorage,
              blockedInventory: _blockedInventory,
              wizard: wizard,
            )
            case Err(:final failure)) {
          log.severe(
            message: 'App Init Error',
            error: failure,
            trace: StackTrace.current,
          );
          _showInitError(failure);
          return;
        }
      } catch (error, stackTrace) {
        log.severe(message: 'App Init Error', error: error, trace: stackTrace);
        _showInitError(error);
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

Future<void> _retryStorage(LegacyImportFailure failure) async {
  final retry = Completer<void>();
  log.warning('Application storage preparation could not complete');
  _showInitError(failure, onRetry: retry.complete);
  await log.flush();
  await retry.future;
}

/// Blocks on an unreadable wallet storage until the user asks to retry. The
/// screen has no action that changes the stored data.
Future<void> _blockedInventory(InventoryRecoveryRequired failure) async {
  final retry = Completer<void>();
  log.severe(
    message: 'Wallet storage unreadable',
    error: failure,
    trace: StackTrace.current,
  );
  runApp(
    BullSupportScope(
      onContactSupport: Support.contactSupport,
      child: InventoryUnreadableScreen(
        onRetry: retry.complete,
        onQuit: () => unawaited(SystemNavigator.pop()),
        extraLocalizations: const [SettingsLocalizations.delegate],
      ),
    ),
  );
  _refreshDiagnosticContextAfterFirstFrame();
  await log.flush();
  await retry.future;
}

void _showInitError(Object error, {VoidCallback? onRetry}) {
  runApp(
    BullSupportScope(
      onContactSupport: Support.contactSupport,
      child: AppInitErrorScreen(
        error: error,
        onRetry: onRetry,
        onMachineTranslationSelected: TranslationWarningBottomSheet.show,
        extraLocalizations: const [SettingsLocalizations.delegate],
      ),
    ),
  );
  _refreshDiagnosticContextAfterFirstFrame();
}

void _refreshDiagnosticContextAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(log.refreshDiagnosticContext());
  });
}
