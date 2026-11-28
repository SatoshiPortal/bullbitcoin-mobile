import 'dart:async';

import '../domain/exchange_access.dart';
import '../domain/exchange_availability.dart';

/// Whether the platform and the network let the user reach the exchange, or,
/// with [onlyWhileOff], whether it is switched off there and could be
/// activated.
Stream<bool> observeExchangeActivationOffer({
  required ExchangePlatform platform,
  required bool Function() currentSuperuser,
  required Stream<bool> superuserChanges,
  required bool onlyWhileOff,
  required ExchangeAccess Function() currentAccess,
  required Stream<ExchangeAccess> Function() watchAccess,
  required Future<bool> Function() networkUnavailable,
}) {
  late final StreamController<bool> controller;
  StreamSubscription<ExchangeAccess>? accessSubscription;
  StreamSubscription<bool>? platformSubscription;
  late ExchangeAccess access;
  var allowed = false;
  var active = true;
  bool? networkAllowed;
  bool? lastValue;
  var networkCheck = 0;

  void publish() {
    final network = networkAllowed;
    if (network == null) return;
    final offered =
        network &&
        allowed &&
        (!onlyWhileOff || access is ExchangeAccessDisabled);
    if (active && !controller.isClosed && offered != lastValue) {
      lastValue = offered;
      controller.add(offered);
    }
  }

  void checkNetwork() {
    final check = ++networkCheck;
    unawaited(() async {
      final unavailable = await networkUnavailable();
      if (check != networkCheck || !active || controller.isClosed) return;
      networkAllowed = !unavailable;
      publish();
    }());
  }

  controller = StreamController<bool>(
    onListen: () {
      access = currentAccess();
      allowed = ExchangeAvailability.platformAllowed(
        platform,
        isSuperuser: currentSuperuser(),
      );
      accessSubscription = watchAccess().listen((value) {
        access = value;
        publish();
        checkNetwork();
      });
      platformSubscription = superuserChanges.listen((value) {
        allowed = ExchangeAvailability.platformAllowed(
          platform,
          isSuperuser: value,
        );
        publish();
      });
      checkNetwork();
    },
    onCancel: () async {
      active = false;
      await Future.wait([
        if (accessSubscription case final subscription?) subscription.cancel(),
        if (platformSubscription case final subscription?)
          subscription.cancel(),
      ]);
    },
  );
  return controller.stream;
}
