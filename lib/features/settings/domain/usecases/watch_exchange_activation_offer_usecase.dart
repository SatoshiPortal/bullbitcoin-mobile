import 'dart:async';

import 'package:exchange/exchange.dart';

/// Whether the platform and the network let the user reach the exchange, or,
/// with [onlyWhileOff], whether it is switched off there and could be
/// activated.
class WatchExchangeActivationOfferUsecase {
  const WatchExchangeActivationOfferUsecase({
    required this._exchange,
    required this._platformAllowed,
    required this._platformChanges,
    this.onlyWhileOff = true,
  });

  final bool onlyWhileOff;

  final Exchange _exchange;
  final bool Function() _platformAllowed;
  final Stream<bool> _platformChanges;

  Stream<bool> execute() {
    late final StreamController<bool> controller;
    StreamSubscription<ExchangeAccess>? accessSubscription;
    StreamSubscription<bool>? platformSubscription;
    var access = _exchange.currentAccess;
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
        final unavailable = await _exchange.networkUnavailable();
        if (check != networkCheck || !active || controller.isClosed) return;
        networkAllowed = !unavailable;
        publish();
      }());
    }

    controller = StreamController<bool>(
      onListen: () {
        allowed = _platformAllowed();
        accessSubscription = _exchange.watchAccess().listen((value) {
          access = value;
          publish();
          checkNetwork();
        });
        platformSubscription = _platformChanges.listen((value) {
          allowed = value;
          publish();
        });
        checkNetwork();
      },
      onCancel: () async {
        active = false;
        await accessSubscription?.cancel();
        await platformSubscription?.cancel();
      },
    );
    return controller.stream;
  }
}
