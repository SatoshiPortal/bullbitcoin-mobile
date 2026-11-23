import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';

/// Whether the trading actions can be used: a signed-in exchange session
/// within the platform and network restrictions.
class WatchQuickActionsVisibilityUsecase {
  const WatchQuickActionsVisibilityUsecase({
    required this._exchange,
    required this._settings,
    required this._platformChanges,
    required this._isIOS,
  });

  final ExchangeFacade _exchange;
  final Preferences _settings;
  final Stream<bool> _platformChanges;
  final bool _isIOS;

  Stream<bool> execute() {
    late final StreamController<bool> controller;
    StreamSubscription<ExchangeAccess>? accessSubscription;
    StreamSubscription<bool>? platformSubscription;
    var access = _exchange.currentAccess;
    var allowed = !_isIOS;
    var platformResolved = !_isIOS;
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
        final unavailable = await _exchange.networkUnavailable();
        if (check != networkCheck || !active || controller.isClosed) return;
        networkAllowed = !unavailable;
        publish();
      }());
    }

    controller = StreamController<bool>(
      onListen: () {
        accessSubscription = _exchange.watchAccess().listen((value) {
          access = value;
          publish();
          checkNetwork();
        });
        checkNetwork();
        platformSubscription = _platformChanges.listen((value) {
          platformChanged = true;
          platformResolved = true;
          allowed = value;
          publish();
        });
        publish();
        if (_isIOS) {
          unawaited(() async {
            var initial = false;
            try {
              initial =
                  ((await _settings.fetch()).fold(
                    (value) => value,
                    (failure) => throw Exception('Preferences read failed'),
                  )).isSuperuser ==
                  true;
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
        await accessSubscription?.cancel();
        await platformSubscription?.cancel();
      },
    );
    return controller.stream;
  }
}
