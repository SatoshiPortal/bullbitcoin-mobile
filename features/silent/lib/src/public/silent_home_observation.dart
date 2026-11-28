import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../silent.dart';

/// A patch to Home's display state. Null fields leave existing values in place.
typedef SilentHomeUpdate = ({
  bool? visible,
  bool? configured,
  int? balanceSat,
  bool loading,
});

/// A Home-owned lifetime over Silent's read-only observation. Never starts scans.
final class SilentHomeObservation {
  final Silent _silent;
  StreamSubscription<Result<SilentUpdate, SilentFailure>>? _updates;
  Set<NetworkEnv>? _networks = const {};
  int _revision = 0;
  bool _closed = false;

  SilentHomeObservation(this._silent);

  void observe(void Function() onInvalidated) {
    if (_closed) return;
    _updates ??= _silent.watchUpdates().listen((result) {
      if (_closed) return;
      switch (result) {
        case Ok(value: SilentBalanceChanged() || SilentSetupChanged()):
          onInvalidated();
        case Ok(value: SilentChainTipChanged()):
          break;
        case Err():
          log.warning('Silent update unavailable');
      }
    });
  }

  /// Retires all prior reads immediately, before the replacement is awaited.
  void catalogReplacing() {
    ++_revision;
    _networks = null;
  }

  void catalogPublished(Set<NetworkEnv> networks) {
    ++_revision;
    _networks = Set.unmodifiable(networks);
  }

  Future<void> refresh(void Function(SilentHomeUpdate) publish) async {
    final networks = _networks;
    if (_closed || networks == null) return;
    final revision = ++_revision;
    bool current() => !_closed && revision == _revision;
    void update({
      bool? visible,
      bool? configured,
      int? balanceSat,
      required bool loading,
    }) => publish((
      visible: visible,
      configured: configured,
      balanceSat: balanceSat,
      loading: loading,
    ));
    void hide() => update(visible: false, balanceSat: 0, loading: false);

    update(loading: true);
    final gate = await _silent.isFeatureEnabled();
    if (!current()) return;
    if (gate is! Ok<bool, SilentFailure>) {
      log.warning('SP feature gate refresh failed category=feature_gate');
      hide();
      return;
    }
    final setup = await _silent.isSetUp();
    if (!current()) return;
    if (setup is! Ok<bool, SilentFailure>) {
      hide();
      return;
    }
    update(configured: setup.value, loading: true);
    if (!gate.value || !setup.value) {
      hide();
      return;
    }
    if (_silent.isScanning) {
      update(loading: false);
      return;
    }
    final result = await _silent.refresh();
    if (!current()) return;
    if (result case Ok(value: final wallet?)) {
      final network = wallet.network;
      if (network != null &&
          NetworkCapabilities.supports(
            network,
            NetworkCapability.silentPayments,
          ) &&
          networks.every((environment) => environment == network.env)) {
        update(
          visible: true,
          configured: true,
          balanceSat: wallet.balance.totalUnifiedSat.value.toInt(),
          loading: false,
        );
        return;
      }
    }
    hide();
  }

  Future<void> close() async {
    _closed = true;
    ++_revision;
    await _updates?.cancel();
  }
}
