import 'dart:ui';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
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
    SqliteNotificationOutbox outbox,
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

  /// Notification storage and the platform plugin are optional to native sync.
  static Future<NotificationsFacade?> initializeBackground(
    String documents,
    Language? language,
    BackgroundTaskResources resources,
  ) async {
    SqliteNotificationOutbox? outbox;
    var retained = false;
    try {
      outbox = openOutbox(documents);
      final notifications = create(outbox, language);
      if (await notifications.initialize() case Err()) {
        log.warning(
          'Background notifications unavailable category=initialization',
        );
        return null;
      }
      resources.onClose(outbox.dispose);
      retained = true;
      log.fine('Background notifications ready');
      return notifications;
    } on Exception {
      log.warning('Background notifications unavailable category=storage');
      return null;
    } finally {
      if (!retained) outbox?.dispose();
    }
  }

  static NotificationCopyBuilder copy(Language? language) {
    final localized = localization(language);
    return (count, chain) => (
      title: localized.receivePaymentReceived,
      body: localized.backgroundPaymentCount(count),
    );
  }
}

/// One app-owned outbox, with retry after transient startup failures.
final class PaymentNotificationStore {
  final Future<String> Function() _documents;
  final Future<Language?> Function() _language;
  Future<NotificationsFacade>? _opening;
  SqliteNotificationOutbox? _outbox;

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
    final outbox = PaymentNotifications.openOutbox(documents);
    _outbox = outbox;
    return PaymentNotifications.create(outbox, language);
  }

  Future<void> close() async {
    try {
      await _opening;
    } finally {
      _outbox?.dispose();
      _outbox = null;
      _opening = null;
    }
  }
}
