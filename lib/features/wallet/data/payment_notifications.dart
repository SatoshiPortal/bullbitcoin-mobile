import 'dart:ui';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:notifications/notifications.dart';
import 'package:path/path.dart' as p;

/// Public notification constants and localized copy belong to the wallet owner.
final class PaymentNotifications {
  static const channelId = 'bull_wallet_payments';
  static const outboxFilename = 'notification_outbox.sqlite';

  static SqliteNotificationOutbox openOutbox(String documents) =>
      SqliteNotificationOutbox(databasePath: p.join(documents, outboxFilename));

  static AppLocalizations localization(Language? language) =>
      lookupAppLocalizations(language?.locale ?? const Locale('en'));

  static NotificationsFacade create(
    NotificationStoreRepository outbox,
    Language? language,
  ) => NotificationsFacade(
    outbox: outbox,
    gateway: FlutterLocalNotificationGateway(
      channelId: channelId,
      // A tap opens the app; no authenticated destination consumer is wired.
      emitDestinations: false,
      channelName: localization(language).receivePaymentReceived,
      androidIconResource: 'ic_launcher_foreground',
    ),
  );

  /// Notification storage and the platform plugin are optional to native
  /// sync. The store is never created nor migrated here: a missing, older or
  /// newer store leaves this run without notifications.
  static Future<NotificationsFacade?> initializeBackground(
    String documents,
    Language? language,
    BackgroundTaskResources resources,
  ) async {
    final NotificationStoreRepository outbox;
    switch (openExistingNotificationStore(p.join(documents, outboxFilename))) {
      case Ok(:final value):
        outbox = value;
      case Err():
        log.warning('Background notifications unavailable category=storage');
        return null;
    }
    resources.onClose(outbox.close);
    final notifications = create(outbox, language);
    if (await notifications.initialize() case Err()) {
      log.warning(
        'Background notifications unavailable category=initialization',
      );
      return null;
    }
    log.fine('Background notifications ready');
    return notifications;
  }

  /// The localized text of an announcement of [count] new payments.
  static ({String title, String body}) Function(int count) copy(
    Language? language,
  ) {
    final localized = localization(language);
    return (count) => (
      title: localized.receivePaymentReceived,
      body: localized.backgroundPaymentCount(count),
    );
  }
}

final class PaymentNotificationStoreUnavailable implements Exception {
  const PaymentNotificationStoreUnavailable();
}

/// One app-owned outbox, with retry after transient startup failures.
final class PaymentNotificationStore {
  final Future<String> Function() _documents;
  final Future<Language?> Function() _language;
  Future<NotificationsFacade>? _opening;
  NotificationStoreRepository? _outbox;

  PaymentNotificationStore(this._documents, this._language);

  Future<NotificationsFacade> open() async {
    final previous = _opening;
    if (previous != null) return previous;
    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<NotificationsFacade> _open() async {
    final documents = await _documents();
    final language = await _language();
    // The foreground is the only creator of the store.
    final outbox = switch (openForegroundNotificationStore(
      p.join(documents, PaymentNotifications.outboxFilename),
    )) {
      Ok(:final value) => value,
      Err() => throw const PaymentNotificationStoreUnavailable(),
    };
    _outbox = outbox;
    return PaymentNotifications.create(outbox, language);
  }

  Future<void> close() async {
    try {
      await _opening;
    } finally {
      await _outbox?.close();
      _outbox = null;
      _opening = null;
    }
  }
}
