import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show Ok;

import '../domain/exchange_access.dart';
import '../domain/exchange_availability.dart';

/// Whether the trading actions can be used: a signed-in exchange session
/// within the platform and network restrictions.
Stream<bool> observeExchangeTradingVisibility({
  required ExchangePlatform platform,
  required Stream<bool> superuserChanges,
  required Preferences? preferences,
  required ExchangeAccess Function() currentAccess,
  required Stream<ExchangeAccess> Function() watchAccess,
  required Future<bool> Function() networkUnavailable,
}) {
  final isIOS = platform == ExchangePlatform.ios;
  late final StreamController<bool> controller;
  StreamSubscription<ExchangeAccess>? accessSubscription;
  StreamSubscription<bool>? platformSubscription;
  late ExchangeAccess access;
  var allowed = !isIOS;
  var platformResolved = !isIOS;
  var platformChanged = false;
  var active = true;
  bool? lastValue;
  bool? networkAllowed;
  var networkCheck = 0;

  void publish() {
    if (!platformResolved) return;
    final network = networkAllowed;
    if (network == null) return;
    final visible =
        network &&
        ExchangeAvailability.resolve(
              platformAllowed: allowed,
              access: access,
            ) ==
            ExchangeAvailability.ready;
    if (active && !controller.isClosed && visible != lastValue) {
      lastValue = visible;
      controller.add(visible);
    }
  }

  // Network changes reconcile access, so each access state rechecks it.
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
      accessSubscription = watchAccess().listen((value) {
        access = value;
        publish();
        checkNetwork();
      });
      checkNetwork();
      platformSubscription = superuserChanges.listen((value) {
        platformChanged = true;
        platformResolved = true;
        allowed = ExchangeAvailability.platformAllowed(
          platform,
          isSuperuser: value,
        );
        publish();
      });
      publish();
      if (isIOS) {
        unawaited(() async {
          var initial = false;
          try {
            if (await preferences?.fetch() case Ok(:final value)) {
              initial = value.isSuperuser == true;
            }
          } on Exception {
            // Fail closed when the platform policy cannot be read.
          }
          if (active && !controller.isClosed && !platformChanged) {
            allowed = initial;
            platformResolved = true;
            publish();
          }
        }());
      }
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
