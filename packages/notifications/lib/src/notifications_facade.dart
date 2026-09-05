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

  NotificationsFacade({required this.gateway, required this.outbox});

  Future<Result<bool, NotificationsFailure>> requestPermission() =>
      gateway.requestPermission();

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

  Future<Result<void, NotificationsFailure>> enqueue(LocalNotification event) =>
      outbox.enqueue(event);

  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopic(String topicId, List<LocalNotification> observedEvents) =>
      outbox.reconcileTopic(topicId, List.unmodifiable(observedEvents));

  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopicsAndEnqueue(
    List<NotificationTopicObservation> observations,
    LocalNotification Function(List<LocalNotification> newEvents)
    aggregateEvent,
  ) => outbox.reconcileTopicsAndEnqueue(
    List.unmodifiable(observations),
    aggregateEvent,
  );

  Future<Result<void, NotificationsFailure>> deliverPending() async {
    final claimed = await outbox.claimPending();
    switch (claimed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        for (final claimed in value) {
          final event = claimed.notification;
          final shown = await gateway.show(
            event,
            platformId: claimed.platformId,
          );
          if (shown case Err(:final failure)) {
            await outbox.release(event.eventId, claimed.claimToken);
            return Err(failure);
          }
          final marked = await outbox.markDelivered(
            event.eventId,
            claimed.claimToken,
          );
          if (marked case Err(:final failure)) return Err(failure);
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
