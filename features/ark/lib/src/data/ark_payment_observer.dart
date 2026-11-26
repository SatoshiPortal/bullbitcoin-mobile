import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

/// Native movements that count as a received payment: successful, incoming,
/// and classified by subsystem and type as an Ark or Lightning receive. Board,
/// renewal, exit and outgoing movements never qualify. Direction does not
/// identify a sender, so a self-send is announced like any other reception.
bool isIncomingPayment(ArkMovement movement) =>
    movement.status == ArkMovementStatus.successful &&
    movement.direction == ArkMovementDirection.incoming &&
    movement.positiveEffectiveAmount &&
    movement.amount != null &&
    movement.amount?.value != BigInt.zero &&
    (movement.kind == ArkMovementKind.payment ||
        movement.kind == ArkMovementKind.lightningReceive);

/// A history that is not complete and fresh proves nothing about what is new.
bool hasFreshPaymentHistory(ArkPassOutcome pass) {
  final snapshot = pass.snapshot;
  return !snapshot.stale &&
      snapshot.recovery == ArkRecoveryStatus.complete &&
      pass.failedStages.isEmpty &&
      pass.failedStageKinds.isEmpty &&
      pass.completedStages.contains(ArkStage.ark);
}

/// Records Ark receptions in the shared payment outbox. A foreground pass is a
/// silent baseline; a background pass announces what the baseline never saw.
/// Exit claim notifications keep their own journal and are forwarded as is.
final class ArkPaymentObserver implements ArkExitObserverPort {
  final NotificationsFacade _notifications;
  final ArkExitObserverPort _exits;
  final bool _foreground;
  final Future<void> Function()? _prepareExits;
  final ({String title, String body}) Function(int count) _copy;

  ArkPaymentObserver({
    required this._notifications,
    required this._exits,
    required this._foreground,
    this._prepareExits,
    required this._copy,
  });

  @override
  Future<void> observe(ArkPassOutcome outcome) async {
    Object? failure;
    StackTrace? trace;
    // Exit observation stays background-only, as before payments existed.
    if (!_foreground) {
      try {
        await _exits.observe(outcome);
      } catch (error, stack) {
        failure = error;
        trace = stack;
      }
    }
    try {
      await _observePayments(outcome);
    } catch (error, stack) {
      log.warning('Ark payment notification failed');
      failure ??= error;
      trace ??= stack;
    }
    if (_foreground) await _prepareExits?.call();
    if (failure != null && trace != null) {
      Error.throwWithStackTrace(failure, trace);
    }
  }

  @override
  Future<void> claimAdmitted(ArkAccountId account, ArkOperation claim) =>
      _exits.claimAdmitted(account, claim);

  Future<void> _observePayments(ArkPassOutcome outcome) async {
    if (!hasFreshPaymentHistory(outcome)) return;
    final account = outcome.snapshot.account;
    final topic = _hash('ark-incoming|${account.canonical}');
    final observation = Observation(topic, [
      for (final movement in outcome.snapshot.movements)
        if (isIncomingPayment(movement)) _hash('$topic|${movement.id}'),
    ]);
    if (_foreground) {
      final recorded = await _notifications.recordForeground(observation);
      if (recorded is Err) {
        throw const FormatException('Ark payment baseline unavailable');
      }
      return;
    }
    final recorded = await _notifications.recordBackground(observation, (
      newEventIds,
    ) {
      final copy = _copy(newEventIds.length);
      return LocalNotification(
        eventId: _hash((newEventIds.toList()..sort()).join('|')),
        title: copy.title,
        body: copy.body,
        createdAt: outcome.snapshot.observedAt,
      );
    });
    if (recorded is Err) {
      throw const FormatException('Ark payment outbox unavailable');
    }
    // Pending aggregates, including earlier failed deliveries, are retried.
    final delivered = await _notifications.deliverPending();
    if (delivered case Err(:final failure)
        when failure is! NotificationsPermissionDeniedFailure) {
      throw const FormatException('Ark payment notification unavailable');
    }
  }
}

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
