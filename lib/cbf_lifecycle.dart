import 'dart:async';

import 'package:bb_mobile/core/background_tasks/cbf_background_sync.dart'
    show stopActiveCbfBackgroundSync, CbfForegroundPresence;
import 'package:bb_mobile/core/background_tasks/cbf_sync_network_policy.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:transaction_sync/transaction_sync.dart';

import 'cbf_background_persistence.dart';
import 'cbf_foreground_sync.dart';

/// Shell lifecycle and platform protection; the package owns native lifetimes.
final class CbfLifecycle {
  final BitcoinSyncRouting routing;
  final WalletMetadataDatasource metadata;
  final Stream<void>? transportChanges;
  final Stream<void>? proxyChanges;
  final CbfSyncNetworkPolicy? networkPolicy;
  final CbfForegroundSync? foregroundSync;
  final CbfBackgroundPersistence? backgroundPersistence;
  final void Function(bool)? onBackgroundProtectionChanged;
  final TargetPlatform _platform;
  final _presence = CbfForegroundPresence();
  StreamSubscription<CbfNetworkPolicyState>? _network;
  StreamSubscription<List<WalletMetadataModel>>? _wallets;
  StreamSubscription<void>? _transports;
  StreamSubscription<void>? _proxies;
  StreamSubscription<void>? _expiration;
  Timer? _ownerWatch;
  bool _resumed = false;
  bool _detached = false;
  bool _disposed = false;
  bool _checkingNetwork = false;
  bool _policiesAvailable = false;
  int _networkValidation = 0;
  int _revision = 0;
  List<WalletMetadataModel> _current = [];
  String? _policy;

  CbfLifecycle({
    required this.routing,
    required this.metadata,
    this.transportChanges,
    this.proxyChanges,
    this.networkPolicy,
    this.foregroundSync,
    this.backgroundPersistence,
    this.onBackgroundProtectionChanged,
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform;

  bool get _desktop =>
      _platform == TargetPlatform.linux ||
      _platform == TargetPlatform.macOS ||
      _platform == TargetPlatform.windows;
  bool get _protected => foregroundSync?.protected ?? false;
  bool get _canRun =>
      !_disposed &&
      _policiesAvailable &&
      !_detached &&
      (_resumed || _protected) &&
      !_checkingNetwork &&
      (networkPolicy?.current.canSync ?? true);

  void start(AppLifecycleState? state) {
    _detached = state == AppLifecycleState.detached;
    _resumed =
        !_detached &&
        (_desktop ||
            state == null ||
            state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive);
    routing.facade.setCbfNativeOwnerMonitor(_presence.trackNativeNode);
    routing.facade.setCbfOwnerPoll(foregroundSync?.heartbeat);
    routing.facade.setCbfForegroundActive(false);
    unawaited(_presence.setActive(_resumed));
    final policy = networkPolicy;
    if (policy != null) {
      routing.facade.setCbfNetworkAdmission(
        () =>
            !_disposed &&
            !_detached &&
            _policiesAvailable &&
            !_checkingNetwork &&
            policy.current.canSync,
      );
      var allowed = policy.current.canSync;
      _network = policy.watch().listen((state) {
        _syncProtection();
        if (state.canSync == allowed) return;
        allowed = state.canSync;
        refresh();
      });
      unawaited(
        policy.start().then((result) {
          if (result is Err) {
            log.warning('Unable to load compact filter network preference');
          }
        }),
      );
    }
    _expiration = backgroundPersistence?.expired.listen((_) {
      if (_disposed || _resumed) return;
      routing.facade.setCbfForegroundActive(false);
      unawaited(routing.facade.stopCbfNodes());
    });
    _transports = transportChanges?.listen(
      (_) => refresh(),
      onError: (Object _) => _policyFailed(),
    );
    _proxies = proxyChanges?.listen(
      (_) => refresh(),
      onError: (Object _) => _policyFailed(),
    );
    _watchWalletPolicies();
    _syncProtection();
  }

  void _watchWalletPolicies() {
    unawaited(_wallets?.cancel());
    _wallets = metadata.watchSyncPolicies().listen((wallets) {
      if (_disposed) return;
      final selected =
          wallets
              .where(
                (wallet) =>
                    wallet.isBitcoin &&
                    wallet.bitcoinSyncSource ==
                        BitcoinSyncSource.compactBlockFilters,
              )
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      final policy = selected
          .map(
            (wallet) =>
                '${wallet.id}:${wallet.birthday?.toIso8601String()}:${wallet.externalPublicDescriptor}:${wallet.internalPublicDescriptor}',
          )
          .join('|');
      if (_policy == policy && _policiesAvailable) return;
      _policiesAvailable = true;
      _policy = policy;
      _current = selected;
      _watchProgress();
      refresh();
    }, onError: (Object _) => _policyFailed());
  }

  void _watchProgress() => foregroundSync?.watch(routing.facade, {
    for (final wallet in _current)
      WalletNetworkKey(
        wallet.id,
        'bitcoin',
        wallet.isTestnet ? 'testnet' : 'mainnet',
      ),
  });

  void _policyFailed() {
    if (_disposed) return;
    _revision++;
    _policiesAvailable = false;
    _policy = null;
    _current = [];
    foregroundSync?.setAllowed(false);
    foregroundSync?.watch(routing.facade, {});
    routing.facade.setCbfForegroundActive(false);
    unawaited(routing.facade.pauseCbfNodes());
    log.warning('Unable to load compact filter wallet or transport policy');
  }

  void _syncProtection() {
    final policy = networkPolicy?.current;
    // An existing service can wait offline without creating nodes/connections.
    // Explicit metered-network restriction uses the unprotected resume fallback.
    foregroundSync?.setAllowed(
      _policiesAvailable &&
          !_detached &&
          (policy == null ||
              policy.initialized &&
                  policy.pauseReason != CbfNetworkPauseReason.mobileData),
    );
    foregroundSync?.setVisible(_resumed && !_detached);
  }

  void protectionChanged() {
    if (_disposed) return;
    final protected = _protected && !_detached;
    onBackgroundProtectionChanged?.call(protected);
    if (protected) {
      // Same owner isolate as native lease polling. Keep the service supervised
      // through offline waits, joins and retry delays, with no independent native
      // lease renewal. A frozen/dead isolate cannot tick this timer.
      _ownerWatch ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => foregroundSync?.heartbeat(),
      );
    } else {
      _ownerWatch?.cancel();
      _ownerWatch = null;
    }
    if (!_resumed) refresh();
  }

  void onStateChange(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(backgroundPersistence?.begin());
      return;
    }
    final wasRunning = _canRun;
    final wasResumed = _resumed;
    _detached = state == AppLifecycleState.detached;
    final resumed =
        !_detached && (state == AppLifecycleState.resumed || _desktop);
    final policy = networkPolicy;
    if (resumed) {
      if (!_policiesAvailable) _watchWalletPolicies();
      unawaited(backgroundPersistence?.end());
    } else {
      unawaited(backgroundPersistence?.begin());
    }
    _resumed = resumed;
    _syncProtection();
    if (resumed &&
        !wasResumed &&
        policy != null &&
        (!_protected || policy.current.wifiOnly)) {
      _checkingNetwork = true;
      final validation = ++_networkValidation;
      // Suspend admission while cost is unknown after an unprotected pause.
      refresh();
      unawaited(() async {
        final result = await policy.reloadPreference();
        await policy.refresh();
        if (validation != _networkValidation || _disposed) return;
        _checkingNetwork = result is Err;
        if (_resumed || _protected) refresh();
      }());
      return;
    }
    if (resumed && !wasResumed && policy != null) {
      // A live protected owner already receives network callbacks. With the
      // default any-network policy it can keep that node during revalidation.
      unawaited(policy.reloadPreference().then((_) => policy.refresh()));
    }
    if (wasResumed == resumed && !_detached) return;
    if (_detached) _networkValidation++;
    // Do not reopen stale cost admission when hidden during a pending read.
    if (_detached || wasRunning != _canRun || !_protected) refresh();
  }

  void refresh() {
    if (_disposed) return;
    _syncProtection();
    final revision = ++_revision;
    final presence = _presence.setActive(true);
    // Publish ownership before looking up a headless worker; a late worker's
    // second presence check then prevents a second native generation.
    final headlessStopped = presence.then<bool>(
      (owns) => owns ? stopActiveCbfBackgroundSync() : false,
    );
    routing.facade.setCbfForegroundActive(false);
    final stopped = routing.facade.pauseCbfNodes();
    unawaited(() async {
      try {
        final result = await stopped;
        final headlessJoined = await headlessStopped;
        final ownsPresence = await presence;
        if (revision != _revision || _disposed) return;
        if (result is Ok) await _presence.nativeStopped();
        if (revision != _revision || _disposed) return;
        if (result is Err || !headlessJoined || !ownsPresence) {
          unawaited(_retryAfterTermination(revision));
          return;
        }
        if (!_canRun) {
          await _presence.setActive(false);
          return;
        }
        if (!await _presence.armNative() || revision != _revision || !_canRun) {
          return;
        }
        final registrations = <WalletSourceRegistration>[];
        for (final wallet in _current) {
          registrations.add(await routing.registration(wallet));
          if (revision != _revision || !_canRun) return;
        }
        _watchProgress();
        routing.facade.setCbfForegroundActive(true);
        final started = await routing.facade.reconcileCbfWallets(registrations);
        if (started is Err) log.warning('Unable to start compact filter nodes');
      } on Exception {
        foregroundSync?.watch(routing.facade, {});
        log.warning('Unable to start compact filter nodes');
      } finally {
        if (!_resumed) await backgroundPersistence?.end();
      }
    }());
  }

  Future<void> _retryAfterTermination(int revision) async {
    while (!_disposed && revision == _revision) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (revision != _revision || _disposed) return;
      final stopped = await routing.facade.stopCbfNodes();
      final headlessJoined = await stopActiveCbfBackgroundSync();
      if (stopped is Ok && headlessJoined && revision == _revision) {
        refresh();
        return;
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _resumed = false;
    _networkValidation++;
    _revision++;
    _ownerWatch?.cancel();
    routing.facade.setCbfOwnerPoll(null);
    routing.facade.setCbfForegroundActive(false);
    onBackgroundProtectionChanged?.call(false);
    final paused = routing.facade.pauseCbfNodes();
    await foregroundSync?.dispose();
    await _wallets?.cancel();
    await _transports?.cancel();
    await _proxies?.cancel();
    await _network?.cancel();
    await _expiration?.cancel();
    await paused;
    while (await routing.facade.stopCbfNodes() is Err) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await backgroundPersistence?.dispose();
    await _presence.nativeStopped();
    await _presence.dispose();
  }
}
