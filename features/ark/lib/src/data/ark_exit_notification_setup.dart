import 'dart:ui';

import 'package:ark/ark_setup.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:notifications/payment_store.dart';
import 'package:primitives/primitives.dart';

import '../../ark_notification_setup.dart';
import 'ark_exit_notifier.dart';
import 'ark_payment_observer.dart';

final class OwnedArkExitNotifier {
  final ArkExitNotifier observer;

  /// Exit claims plus incoming payments: what the client observes.
  final ArkPaymentObserver combined;
  final LifecycleHandle _observerHandle;
  final LifecycleHandle _allocatorHandle;

  OwnedArkExitNotifier(
    this.observer,
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
}) async {
  final allocator = PaymentNotificationStore(
    () async => documents,
    () async => PaymentNotifications.gateway(locale),
  );
  final allocatorHandle = admission.track(allocator.close);
  try {
    final outbox = await allocator.open();
    final gateway = switch (await initializeArkNotifications(locale)) {
      Ok(:final value) => value,
      Err() => throw const FormatException('Ark notifications unavailable'),
    };
    final copy = arkExitClaimableCopy(locale);
    final observer = ArkExitNotifier.open(
      path: '$directory/exit-notices.sqlite',
      foreground: true,
      allocator: outbox,
      notifications: gateway,
      budget: const ArkUnlimitedStageBudget(),
      title: copy.title,
      body: copy.body,
    );
    try {
      final handle = admission.track(() async => observer.close());
      final combined = ArkPaymentObserver(
        notifications: outbox,
        exits: observer,
        foreground: true,
        copy: PaymentNotifications.copy(locale),
      );
      return OwnedArkExitNotifier(observer, combined, handle, allocatorHandle);
    } catch (_) {
      observer.close();
      rethrow;
    }
  } catch (_) {
    await allocatorHandle.close();
    rethrow;
  }
}
