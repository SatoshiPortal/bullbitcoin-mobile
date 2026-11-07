import 'package:bull_logger/bull_logger.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';

import 'domain/local_notification.dart';
import 'domain/local_notification_gateway.dart';
import 'domain/notification_destination.dart';
import 'domain/notification_outbox_port.dart';
import 'domain/notifications_failure.dart';
import 'domain/notification_payload_codec.dart';
import 'domain/notification_reconcile_result.dart';

final class NotificationsFacade {
  final LocalNotificationGateway gateway;
  final NotificationOutboxPort outbox;
  final List<String> _unpersistedResponses = [];
  bool? _allowed;

  NotificationsFacade({required this.gateway, required this.outbox});

  Future<Result<void, NotificationsFailure>> initialize() =>
      gateway.initialize((payload) {
        final persisted = outbox.persistResponse(payload);
        if (persisted case Err()) _unpersistedResponses.add(payload);
        return persisted;
      });

  Future<Result<void, NotificationsFailure>> retryUnpersistedResponses() async {
    NotificationsFailure? firstFailure;
    final remaining = <String>[];
    for (final payload in _unpersistedResponses) {
      final persisted = outbox.persistResponse(payload);
      switch (persisted) {
        case Ok():
          break;
        case Err(:final failure):
          firstFailure ??= failure;
          remaining.add(payload);
      }
    }
    _unpersistedResponses
      ..clear()
      ..addAll(remaining);
    return firstFailure == null ? const Ok(null) : Err(firstFailure);
  }

  /// Records discoveries from a sync completed in foreground, never a read.
  /// On first completion, baselineEvents initializes history without marking
  /// it seen. An existing baseline ignores baselineEvents.
  Future<Result<void, NotificationsFailure>> recordObserved(
    String topicId,
    List<LocalNotification> observedEvents, {
    List<LocalNotification> baselineEvents = const [],
    bool onlyNew = false,
  }) => outbox.recordObserved(
    topicId,
    List.unmodifiable(observedEvents),
    baselineEvents: List.unmodifiable(baselineEvents),
    onlyNew: onlyNew,
  );

  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopicsAndEnqueue(
    List<NotificationTopicObservation> observations,
    LocalNotification Function(List<LocalNotification> newEvents)
    aggregateEvent,
  ) async {
    final result = await outbox.reconcileTopicsAndEnqueue(
      List.unmodifiable(observations),
      aggregateEvent,
    );
    if (result case Ok(:final value)) {
      log.fine(
        'Notifications reconciled pending=${value.pendingCount} skipped_topics=${value.skippedTopicCount}',
      );
    }
    return result;
  }

  Future<Result<void, NotificationsFailure>> deliverPending() async {
    final enabled = await gateway.isEnabled();
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

  Future<Result<void, NotificationsFailure>> _settlePending({
    required bool show,
  }) async {
    var shownCount = 0;
    var seenCount = 0;
    var deniedCount = 0;
    final claimed = await outbox.claimPending();
    switch (claimed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        for (final claimed in value) {
          final event = claimed.notification;
          // Claimed before the app showed these payments: settle silently.
          final bool alreadySeen;
          switch (await outbox.isSeen(event.eventId)) {
            case Ok(:final value):
              alreadySeen = value;
            case Err(:final failure):
              final released = await outbox.release(
                event.eventId,
                claimed.claimToken,
              );
              if (released case Err(:final failure)) return Err(failure);
              return Err(failure);
          }
          if (show && !alreadySeen) {
            final shown = await gateway.show(
              event,
              platformId: claimed.platformId,
            );
            if (shown case Err(:final failure)) {
              final released = await outbox.release(
                event.eventId,
                claimed.claimToken,
              );
              if (released case Err(:final failure)) return Err(failure);
              return Err(failure);
            }
          }
          final marked = await outbox.markDelivered(
            event.eventId,
            claimed.claimToken,
          );
          if (marked case Err(:final failure)) return Err(failure);
          if (alreadySeen) {
            seenCount++;
          } else if (show) {
            shownCount++;
          } else {
            deniedCount++;
          }
        }
        if (value.isNotEmpty) {
          log.fine(
            'Notifications settled shown=$shownCount seen=$seenCount denied=$deniedCount',
          );
        }
    }
    return const Ok(null);
  }

  Future<Result<NotificationDestination?, NotificationsFailure>>
  consumePendingDestination() async {
    final response = await outbox.consumeResponse();
    switch (response) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value == null) return const Ok(null);
        return decodeDestination(value).map((destination) => destination);
    }
  }

  static int hashCandidateFor(String eventId) {
    final digest = sha256.convert(utf8.encode(eventId)).bytes;
    final value = ByteData.sublistView(Uint8List.fromList(digest)).getUint32(0);
    return value & 0x7fffffff;
  }

  static String encodeDestination(NotificationDestination destination) =>
      const NotificationPayloadCodec().encode(destination);

  static Result<NotificationDestination, NotificationsFailure>
  decodeDestination(String payload) =>
      const NotificationPayloadCodec().decode(payload);
}
