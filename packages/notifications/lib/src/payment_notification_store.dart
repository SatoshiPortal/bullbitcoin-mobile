import 'package:bull_logger/bull_logger.dart';
import 'package:path/path.dart' as p;
import 'package:primitives/primitives.dart';

import '../notifications.dart';

const paymentNotificationOutboxFilename = 'notification_outbox.sqlite';

/// Existing outbox only. Its native storage remains open until the task closes.
Future<NotificationsFacade?> openBackgroundPaymentNotifications(
  String documents, {
  required LocalNotificationPort Function() gateway,
  required void Function(Future<void> Function()) onClose,
}) async {
  final NotificationStoreRepository outbox;
  switch (openExistingNotificationStore(
    p.join(documents, paymentNotificationOutboxFilename),
  )) {
    case Ok(:final value):
      outbox = value;
    case Err():
      log.warning('Background notifications unavailable category=storage');
      return null;
  }
  onClose(outbox.close);
  final notifications = NotificationsFacade(outbox: outbox, gateway: gateway());
  if (await notifications.initialize() case Err()) {
    log.warning('Background notifications unavailable category=initialization');
    return null;
  }
  log.fine('Background notifications ready');
  return notifications;
}

final class PaymentNotificationStoreUnavailable implements Exception {
  const PaymentNotificationStoreUnavailable();
}

/// One app-owned outbox, with retry after transient startup failures.
final class PaymentNotificationStore {
  final Future<String> Function() _documents;
  final Future<LocalNotificationPort> Function() _gateway;
  Future<NotificationsFacade>? _opening;
  NotificationStoreRepository? _outbox;

  PaymentNotificationStore(this._documents, this._gateway);

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
    final gateway = await _gateway();
    // The foreground is the only creator of the store.
    final outbox = switch (openForegroundNotificationStore(
      p.join(documents, paymentNotificationOutboxFilename),
    )) {
      Ok(:final value) => value,
      Err() => throw const PaymentNotificationStoreUnavailable(),
    };
    _outbox = outbox;
    return NotificationsFacade(outbox: outbox, gateway: gateway);
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
