import 'linux_cbf_network_signals.dart';
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transaction_sync/transaction_sync.dart';

abstract interface class CbfWifiOnlyPreferenceStore {
  Future<bool> read();
  Future<void> write(bool enabled);
}

final class SharedPreferencesCbfWifiOnlyPreferenceStore
    implements CbfWifiOnlyPreferenceStore {
  static const key = 'cbf_sync_wifi_only';

  const SharedPreferencesCbfWifiOnlyPreferenceStore();

  @override
  Future<bool> read() async {
    final preferences = await SharedPreferences.getInstance();
    // Background engines have separate preference caches.
    await preferences.reload();
    return preferences.getBool(key) ?? false;
  }

  @override
  Future<void> write(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(key, enabled)) {
      throw const FormatException('Unable to save sync network preference');
    }
  }
}

typedef CbfNetworkSignal = ({bool available, bool? metered});
typedef ReadCbfNetworkSignal = Future<CbfNetworkSignal?> Function();

/// Network observation only. This object never owns a node or renews its lease.
/// The composition root applies its admission state to foreground/background work.
final class CbfSyncNetworkPolicy implements CbfNetworkPolicyPort {
  static const channelName = 'com.bullbitcoin.mobile/cbf_network';

  final CbfWifiOnlyPreferenceStore _preferences;
  final LinuxCbfNetworkSignals? _linuxSignals;
  final Future<List<ConnectivityResult>> Function() _readConnectivity;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final MethodChannel _channel;
  final bool _nativeSignals;
  final ReadCbfNetworkSignal? _readSignal;
  final Stream<CbfNetworkSignal>? _signalChanges;
  final _changes = StreamController<CbfNetworkPolicyState>.broadcast(
    sync: true,
  );
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<CbfNetworkSignal>? _signalSubscription;
  CbfNetworkPolicyState _current = const CbfNetworkPolicyState();
  CbfNetworkSignal _network = (available: false, metered: null);
  Future<Result<void, WalletTransactionSyncFailure>>? _starting;
  Future<void> _writes = Future.value();
  bool _initialized = false;
  bool _networkKnown = false;
  bool _wifiOnly = false;
  bool _mobileDataOverride = false;
  bool _disposed = false;
  int _networkRevision = 0;
  int _preferenceRevision = 0;

  CbfSyncNetworkPolicy({
    this._preferences = const SharedPreferencesCbfWifiOnlyPreferenceStore(),
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? readConnectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    this._channel = const MethodChannel(channelName),
    bool? nativeSignals,
    this._readSignal,
    this._signalChanges,
  }) : _readConnectivity =
           readConnectivity ??
           (connectivity ?? Connectivity()).checkConnectivity,
       _connectivityChanges =
           connectivityChanges ??
           (connectivity ?? Connectivity()).onConnectivityChanged,
       _nativeSignals = nativeSignals ?? (Platform.isAndroid || Platform.isIOS),
       _linuxSignals =
           Platform.isLinux &&
               nativeSignals == null &&
               _readSignal == null &&
               _signalChanges == null &&
               readConnectivity == null &&
               connectivityChanges == null
           ? LinuxCbfNetworkSignals()
           : null;

  @override
  CbfNetworkPolicyState get current => _current;

  @override
  Stream<CbfNetworkPolicyState> watch() => Stream.multi((controller) {
    if (_disposed) {
      controller.close();
      return;
    }
    final subscription = _changes.stream.listen(
      controller.add,
      onDone: controller.close,
    );
    controller.add(_current);
    controller.onCancel = subscription.cancel;
  });

  Future<Result<void, WalletTransactionSyncFailure>> start() =>
      _starting ??= _start();

  Future<Result<void, WalletTransactionSyncFailure>> _start() async {
    if (_disposed) return const Err(WalletSyncDeferredFailure());
    if (_nativeSignals) _channel.setMethodCallHandler(_nativeCall);
    _connectivitySubscription = _connectivityChanges.listen(
      (_) => unawaited(refresh()),
      onError: (Object _) {
        // Transport-monitor failure is not proof that an existing peer is lost.
      },
    );
    _signalSubscription = (_signalChanges ?? _linuxSignals?.changes)?.listen(
      _acceptSignal,
      onError: (Object _) {},
    );
    final result = await reloadPreference();
    await refresh();
    return result;
  }

  /// Refresh this on app resume; Android may suppress background notifications.
  /// Transport reports are hints. An OS cost/validation signal takes precedence.
  Future<void> refresh() async {
    if (_disposed) return;
    final revision = ++_networkRevision;
    List<ConnectivityResult>? transports;
    try {
      transports = await _readConnectivity();
    } on Exception {
      // A missing desktop D-Bus/plugin is unknown, not an Internet outage.
    }
    CbfNetworkSignal? native;
    try {
      final reader = _readSignal ?? _linuxSignals?.read;
      if (reader != null) {
        native = await reader();
      } else if (_nativeSignals) {
        native = _parseSignal(await _channel.invokeMethod<Object?>('read'));
      }
    } on Exception {
      // Older host runners fall back to connectivity_plus, without probing.
    }
    if (_disposed || revision != _networkRevision) return;
    final values = transports;
    _networkKnown = true;
    _network =
        native ??
        (values == null
            ? (available: true, metered: null)
            : (
                available: values.any(
                  (value) => value != ConnectivityResult.none,
                ),
                // A mobile engine without its native adapter must not infer
                // that a Wi-Fi hotspot is free (headless engines included).
                metered: (_nativeSignals || _linuxSignals != null)
                    ? null
                    : values.contains(ConnectivityResult.mobile)
                    ? true
                    : values.contains(ConnectivityResult.wifi) ||
                          values.contains(ConnectivityResult.ethernet)
                    ? false
                    : null,
              ));
    _publish();
  }

  /// SharedPreferences is cached per engine; call on resume/background admission.
  Future<Result<void, WalletTransactionSyncFailure>> reloadPreference() async {
    final revision = ++_preferenceRevision;
    try {
      await _writes;
      final enabled = await _preferences.read();
      if (_disposed) return const Err(WalletSyncDeferredFailure());
      if (revision == _preferenceRevision) {
        _wifiOnly = enabled;
        _initialized = true;
        _publish();
      }
      return const Ok(null);
    } on Exception {
      // Do not silently replace a previously saved cost restriction with false.
      return const Err(SourceStorageFailure());
    }
  }

  Future<void> _nativeCall(MethodCall call) async {
    if (call.method != 'changed' || _disposed) return;
    final signal = _parseSignal(call.arguments);
    if (signal != null) _acceptSignal(signal);
  }

  static CbfNetworkSignal? _parseSignal(Object? value) {
    if (value case {
      'available': final bool available,
      'metered': final bool? metered,
    }) {
      return (available: available, metered: metered);
    }
    return null;
  }

  /// Injection seam for platform-independent lifecycle/network regression tests.
  void _acceptSignal(CbfNetworkSignal signal) {
    if (_disposed) return;
    ++_networkRevision;
    _networkKnown = true;
    _network = signal;
    _publish();
  }

  @override
  Future<Result<void, WalletTransactionSyncFailure>> setWifiOnly(bool enabled) {
    ++_preferenceRevision;
    final result = _writes.then<Result<void, WalletTransactionSyncFailure>>((
      _,
    ) async {
      if (_disposed) return const Err(WalletSyncDeferredFailure());
      try {
        await _preferences.write(enabled);
        if (_disposed) return const Err(WalletSyncDeferredFailure());
        _wifiOnly = enabled;
        _initialized = true;
        // An explicit new preference choice starts a new consent decision.
        _mobileDataOverride = false;
        _publish();
        return const Ok(null);
      } on Exception {
        return const Err(SourceStorageFailure());
      }
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  void continueOnMobileData() {
    if (_disposed || !_wifiOnly) return;
    _mobileDataOverride = true;
    _publish();
  }

  void _publish() {
    if (_disposed) return;
    final state = CbfNetworkPolicyState(
      initialized: _initialized && _networkKnown,
      available: _network.available,
      metered: _network.metered,
      wifiOnly: _wifiOnly,
      mobileDataOverride: _mobileDataOverride,
    );
    if (state == _current) return;
    _current = state;
    _changes.add(state);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_networkRevision;
    ++_preferenceRevision;
    if (_nativeSignals) _channel.setMethodCallHandler(null);
    await _connectivitySubscription?.cancel();
    await _signalSubscription?.cancel();
    await _linuxSignals?.dispose();
    await _writes;
    await _changes.close();
  }
}
