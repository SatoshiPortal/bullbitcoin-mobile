import 'dart:ui';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:notifications/notifications.dart'
    show NotificationsFailure, ScheduledNotificationPort;
import 'package:notifications/payment_store.dart';
import 'package:primitives/primitives.dart';

import '../../ark_notification_setup.dart';
import 'ark_exit_notifier.dart';
import 'ark_payment_observer.dart';

final class OwnedArkExitNotifier {
  /// Exit claims plus incoming payments: what the client observes.
  final ArkPaymentObserver combined;
  final LifecycleHandle _observerHandle;
  final LifecycleHandle _allocatorHandle;

  OwnedArkExitNotifier(
    this.combined,
    this._observerHandle,
    this._allocatorHandle,
  );

  Future<void> close() async {
    try {
      await _observerHandle.close();
    } finally {
      await _allocatorHandle.close();
    }
  }
}

Future<OwnedArkExitNotifier> openForegroundArkExitNotifier({
  required String documents,
  required String directory,
  required Locale locale,
  required RuntimeAdmission admission,
  Future<Result<ScheduledNotificationPort, NotificationsFailure>> Function(
        Locale,
      )
      initializeExits =
      initializeArkNotifications,
}) async {
  final allocator = PaymentNotificationStore(
    () async => documents,
    () async => PaymentNotifications.gateway(locale),
  );
  final allocatorHandle = admission.track(allocator.close);
  try {
    final outbox = await allocator.open();
    final exits = LazyArkExitObserver(() async {
      final gateway = switch (await initializeExits(locale)) {
        Ok(:final value) => value,
        Err() => throw const FormatException('Ark notifications unavailable'),
      };
      final copy = arkExitClaimableCopy(locale);
      return ArkExitNotifier.open(
        path: '$directory/exit-notices.sqlite',
        foreground: true,
        allocator: outbox,
        notifications: gateway,
        budget: const ArkUnlimitedStageBudget(),
        title: copy.title,
        body: copy.body,
      );
    });
    final handle = admission.track(exits.close);
    Future<void> prepareExits() async {
      try {
        await exits.prepare();
      } on Exception {
        log.warning('Ark exit notifications unavailable');
      }
    }

    await prepareExits();
    final combined = ArkPaymentObserver(
      notifications: outbox,
      exits: exits,
      prepareExits: prepareExits,
      foreground: true,
      copy: PaymentNotifications.copy(locale),
    );
    return OwnedArkExitNotifier(combined, handle, allocatorHandle);
  } catch (_) {
    await allocatorHandle.close();
    rethrow;
  }
}

/// A failed open is retried by the next observation or claim admission.
final class LazyArkExitObserver implements ArkExitObserverPort {
  final Future<ArkExitNotifier> Function() _open;
  Future<ArkExitNotifier>? _opening;

  LazyArkExitObserver(this._open);

  Future<ArkExitNotifier> _observer() async {
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<void> prepare() async {
    await _observer();
  }

  @override
  Future<void> observe(ArkPassOutcome outcome) async =>
      (await _observer()).observe(outcome);

  @override
  Future<void> claimAdmitted(ArkAccountId account, ArkOperation claim) async =>
      (await _observer()).claimAdmitted(account, claim);

  Future<void> close() async {
    final observer = await _opening;
    observer?.close();
    _opening = null;
  }
}
