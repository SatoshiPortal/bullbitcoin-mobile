import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import 'domain/local_notification.dart';
import 'domain/ports/local_notification_port.dart';
import 'domain/notifications_failure.dart';
import 'domain/observation.dart';
import 'domain/repositories/notification_store_repository.dart';

final class NotificationsFacade {
  final LocalNotificationPort _gateway;
  final NotificationStoreRepository _outbox;
  bool? _allowed;

  NotificationsFacade({required this._gateway, required this._outbox});

  Future<Result<void, NotificationsFailure>> initialize() =>
      _gateway.initialize();

  /// The complete history of a sync completed in the foreground, never a
  /// snapshot reload. What it holds is never announced.
  Future<Result<void, NotificationsFailure>> recordForeground(
    Observation observation,
  ) => _outbox.recordForeground(observation);

  /// The complete history of a background sync: events stored for the first
  /// time become one pending aggregate, built by [aggregate].
  Future<Result<BackgroundObservation, NotificationsFailure>> recordBackground(
    Observation observation,
    LocalNotification Function(List<String> newEventIds) aggregate,
  ) async {
    final result = await _outbox.recordBackground(observation, aggregate);
    if (result case Ok(:final value)) {
      log.fine('Notifications observed outcome=${value.name}');
    }
    return result;
  }

  Future<Result<void, NotificationsFailure>> deliverPending() async {
    final enabled = await _gateway.isEnabled();
    if (enabled case Ok(:final value) when value != _allowed) {
      _allowed = value;
      log.config('Notification permission changed allowed=$value');
    }
    switch (enabled) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        // A show would be a silent no-op. Settle without showing: granting
        // the permission later announces only payments seen from then on,
        // never a backlog of old ones.
        final dropped = await _settlePending(show: false);
        if (dropped case Err(:final failure)) return Err(failure);
        return const Err(NotificationsPermissionDeniedFailure());
      case Ok():
        return _settlePending(show: true);
    }
  }

  /// One aggregate at a time: a failure leaves the others pending, unclaimed.
  Future<Result<void, NotificationsFailure>> _settlePending({
    required bool show,
  }) async {
    var count = 0;
    while (true) {
      final ClaimedNotification claim;
      switch (await _outbox.claimNext()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: null):
          if (count > 0) {
            log.fine(
              'Notifications settled shown=${show ? count : 0} denied=${show ? 0 : count}',
            );
          }
          return const Ok(null);
        case Ok(:final value?):
          claim = value;
      }
      if (show) {
        final shown = await _gateway.show(
          claim.notification,
          platformId: claim.platformId,
        );
        if (shown case Err(:final failure)) {
          final released = await _outbox.release(claim);
          if (released case Err(:final failure)) return Err(failure);
          return Err(failure);
        }
      }
      final settled = await _outbox.settle(claim);
      if (settled case Err(:final failure)) return Err(failure);
      count++;
    }
  }
}
