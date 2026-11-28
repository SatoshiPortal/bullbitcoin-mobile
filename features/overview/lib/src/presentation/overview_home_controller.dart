import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, VoidCallback, setEquals;
import 'package:preferences/preferences.dart' show AmountDisplayPreferences;
import 'package:primitives/primitives.dart' show BitcoinNetwork, NetworkEnv, Ok;
import 'package:silent/silent.dart' show SilentHomeObservation;
import 'package:swap_feature/swap_feature.dart'
    show SwapActivity, SwapHomeServerCheck;
import 'package:swaps/swaps.dart' show Swap;
import 'package:sync/sync.dart' show WalletKey;

import '../domain/home_network_warnings.dart';
import '../domain/home_sync_pass.dart';
import '../domain/ongoing_swaps.dart';
import '../domain/overview_amount_display.dart';
import '../domain/overview_catalogue.dart';
import '../domain/overview_home_source.dart';
import '../domain/overview_load_failure.dart';
import '../domain/sync_trigger.dart';
import 'overview_home_state.dart';

/// Home's presentation and lifecycle coordinator.
///
/// It owns no data: the Overview catalogue stays the row and balance source,
/// and the Overview coordinator stays the only sync queue. This controller
/// copies the catalogue's current projection, joins the owner observations
/// Home needs (amount preferences, Electrum outcomes, Silent, swaps, backups)
/// and publishes one immutable [OverviewHomeState].
///
/// Everything it calls is either Overview's own domain or a narrow public
/// capability injected by the composition root. It never reads another
/// feature's internals and never opens a wallet itself.
final class OverviewHomeController
    implements ValueListenable<OverviewHomeState> {
  final OverviewHomeSource _catalogue;
  final HomeSyncPass _sync;
  final OverviewAmountDisplay _amountDisplay;
  final OngoingSwaps _ongoingSwaps;
  final SwapActivity? _swapActivity;
  final SwapHomeServerCheck _swapServerCheck;
  final Future<bool?> Function() _readBackupWarning;
  final Future<bool?> Function(WalletKey) _readPhysicalBackup;
  final Future<bool> Function() _proxyNeedsAttention;
  final SilentHomeObservation _silentHome;

  final ValueNotifier<OverviewHomeState> _state = ValueNotifier(
    const OverviewHomeState.initial(),
  );

  late final HomeNetworkWarnings _networkWarnings = HomeNetworkWarnings(
    _proxyNeedsAttention,
  );
  late final StreamSubscription<void> _catalogueSubscription;
  late final StreamSubscription<HomeSyncStart> _startedSubscription;
  late final StreamSubscription<WalletKey> _finishedSubscription;
  late final StreamSubscription<HomeElectrumOutcome> _electrumSubscription;
  late final StreamSubscription<bool> _activitySubscription;
  late final StreamSubscription<AmountDisplayPreferences?>
  _amountDisplaySubscription;

  OverviewCatalogueStatus _status = OverviewCatalogueStatus.replacing;
  var _wallets = <OverviewHomeWallet>[];
  final _syncing = <WalletKey>{};
  final _syncRuns = <WalletKey, int>{};
  final _swaps = <Swap>[];
  var _warnings = <WalletWarning>[];
  var _swapServerUnreachable = false;
  OverviewLoadFailure? _syncFailure;
  AmountDisplayPreferences? _amountPreferences;
  var _isRefreshing = false;
  var _isSyncPassActive = false;
  bool? _backupNeeded;
  bool? _physicalBackupNeeded;
  int _physicalBackupVersion = 0;
  Set<WalletKey> _defaultKeys = {};
  var _backupDismissed = false;
  var _silentVisible = false;
  var _silentConfigured = false;
  var _silentBalanceSat = 0;
  var _silentLoading = false;
  var _backupChecksStarted = false;

  Future<void> _electrumUpdates = Future.value();
  Future<void>? _refresh;
  var _refreshGeneration = 0;
  var _swapsReadVersion = 0;
  var _swapCheckVersion = 0;
  var _backupReadVersion = 0;
  var _silentRetired = false;
  String? _publishedMembership;
  var _closed = false;

  /// [syncStarted] and [syncFinished] carry per-wallet sync activity;
  /// [electrumResults] carries only outcomes worth warning about.
  OverviewHomeController({
    required this._catalogue,
    required this._sync,
    required this._amountDisplay,
    required this._ongoingSwaps,
    required this._swapServerCheck,
    required this._readBackupWarning,
    required this._readPhysicalBackup,
    required this._proxyNeedsAttention,
    required this._silentHome,
    required Stream<HomeSyncStart> syncStarted,
    required Stream<WalletKey> syncFinished,
    required Stream<HomeElectrumOutcome> electrumResults,
    this._swapActivity,
  }) {
    _catalogueSubscription = _catalogue.changes.listen(
      (_) => _onCatalogueChanged(),
    );
    _startedSubscription = syncStarted.listen(_onSyncStarted);
    _finishedSubscription = syncFinished.listen(_onSyncFinished);
    _electrumSubscription = electrumResults.listen(_enqueueElectrumOutcome);
    _activitySubscription = _sync.activity.listen(_onSyncActivity);
    _amountDisplaySubscription = _amountDisplay.watch().listen(
      _onAmountDisplay,
    );
    _silentHome.observe(_refreshSilent);
    // The activity stream does not replay: a pass already draining when Home
    // mounts must still show its progress.
    _isSyncPassActive = _sync.isSyncPassActive;
    _onCatalogueChanged();
    unawaited(_readSwaps());
  }

  /// Starts backup reads only after their owners and wallet admission exist.
  /// Early catalogue or sync events need no queue: activation reads the
  /// current defaults. Repeated calls, including after close, are inert.
  void startBackupChecks() {
    if (_closed || _backupChecksStarted) return;
    _backupChecksStarted = true;
    unawaited(_verifyBackup());
  }

  /// The screen listens; nothing else mutates this state.
  ValueListenable<OverviewHomeState> get state => _state;

  @override
  OverviewHomeState get value => _state.value;

  @override
  void addListener(VoidCallback listener) {
    if (!_closed) _state.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (!_closed) _state.removeListener(listener);
  }

  OverviewHomeState get current => _state.value;

  bool get isClosed => _closed;

  /// Automatic visibility trigger: request the coordinator's routine pass
  /// without waiting for it. The indicator still tracks the round.
  void refreshVisible() {
    if (_closed) return;
    unawaited(_beginRefresh(trigger: SyncTrigger.automatic, retrySwaps: false));
  }

  /// Pull-to-refresh. Never throws: a failed round is already surfaced in
  /// [state], and a `RefreshIndicator` callback must not complete with an
  /// error. The returned future resolves once this round settled, so the
  /// spinner stops after bitcoin and liquid both ran.
  Future<void> refresh() async {
    if (_closed) return;
    final catalogue = _catalogue;
    if (catalogue is OverviewHomeMembershipRetry) {
      (catalogue as OverviewHomeMembershipRetry).retryMembership();
    }
    await _beginRefresh(trigger: SyncTrigger.user, retrySwaps: true);
  }

  /// Wait for the refresh already represented by the UI, without requesting
  /// another one. Used when the indicator auto-shows for a background round.
  Future<void> waitForRefresh() async {
    final pending = _refresh;
    if (pending != null) await pending;
  }

  /// Recheck backup status without requesting a sync or refreshing swaps.
  Future<void> verifyBackup() async {
    if (_closed) return;
    await _verifyBackup();
  }

  /// Session-scoped, like the legacy Home: dismissing hides the card until the
  /// next launch, it is not persisted.
  void dismissBackupWarning() {
    if (_closed || _backupDismissed) return;
    _backupDismissed = true;
    _publish();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _refreshGeneration++;
    _networkWarnings.close();
    await _catalogueSubscription.cancel();
    await _startedSubscription.cancel();
    await _finishedSubscription.cancel();
    await _electrumSubscription.cancel();
    await _activitySubscription.cancel();
    await _amountDisplaySubscription.cancel();
    await _silentHome.close();
    _state.dispose();
  }

  Future<void> _beginRefresh({
    required SyncTrigger trigger,
    required bool retrySwaps,
  }) {
    if (_closed) return Future.value();
    final generation = ++_refreshGeneration;
    _swapsReadVersion++;
    _backupReadVersion++;
    _isRefreshing = true;
    _publish();
    unawaited(_checkSwapServer());
    final refresh = _performRefresh(
      generation: generation,
      trigger: trigger,
      retrySwaps: retrySwaps,
    );
    _refresh = refresh;
    return refresh;
  }

  Future<void> _performRefresh({
    required int generation,
    required SyncTrigger trigger,
    required bool retrySwaps,
  }) async {
    if (retrySwaps) unawaited(_swapActivity?.retryOngoingSwaps());
    _refreshSilent();
    final outcome = await _sync.sync(trigger: trigger);
    if (_closed || generation != _refreshGeneration) return;
    // A busy pass is still someone else's live work, not a failure. Anything
    // else that failed means the rows kept their previous, possibly stale,
    // balances.
    await _readSwaps();
    if (_closed || generation != _refreshGeneration) return;
    _syncFailure = switch (outcome) {
      HomeSyncOutcome.completed || HomeSyncOutcome.busy => null,
      HomeSyncOutcome.failed => OverviewLoadFailure.balancesMayBeStale,
    };
    unawaited(_verifyBackup());
    _refreshSilent();
    if (generation == _refreshGeneration) _isRefreshing = false;
    _publish();
  }

  void _onCatalogueChanged() {
    if (_closed) return;
    final snapshot = _catalogue.snapshot;
    if (snapshot.status == OverviewCatalogueStatus.revoked ||
        snapshot.status == OverviewCatalogueStatus.replacing ||
        snapshot.status == OverviewCatalogueStatus.closed) {
      _refreshGeneration++;
      _swapsReadVersion++;
      _swapCheckVersion++;
      _backupReadVersion++;
      _physicalBackupVersion++;
      _physicalBackupNeeded = null;
      _backupNeeded = null;
      _defaultKeys = {};
      _isRefreshing = false;
      _syncFailure = null;
      _swaps.clear();
      _warnings = [];
      _swapServerUnreachable = false;
      _networkWarnings.reset();
      _syncRuns.clear();
    }
    _status = snapshot.status;
    _wallets = snapshot.wallets;
    final defaults = {
      for (final wallet in _wallets)
        if (wallet.entry.isDefault) wallet.entry.key,
    };
    if (!setEquals(defaults, _defaultKeys)) {
      _defaultKeys = defaults;
      _physicalBackupNeeded = null;
      unawaited(_verifyBackup());
    }
    final keys = {for (final wallet in _wallets) wallet.entry.key};
    _syncing.removeWhere((key) => !keys.contains(key));
    _updateSilent(snapshot);
    _publish();
  }

  Future<void> _readSwaps() async {
    final version = ++_swapsReadVersion;
    final result = await _ongoingSwaps.read();
    if (_closed || version != _swapsReadVersion) return;
    // A read failure is not evidence that there are no swaps in progress:
    // keep the last known notices instead of emptying them.
    if (result case Ok(:final value)) {
      _swaps
        ..clear()
        ..addAll(value);
      _publish();
    }
  }

  Future<void> _checkSwapServer() async {
    final version = ++_swapCheckVersion;
    final reachable = await _swapServerCheck.reachable();
    if (_closed || version != _swapCheckVersion) return;
    if (_swapServerUnreachable == !reachable) return;
    _swapServerUnreachable = !reachable;
    _publish();
  }

  /// Retires the previous answer immediately, like the legacy Home did: a
  /// pending read must not leave a stale warning on screen.
  Future<void> _verifyBackup() async {
    if (_closed || !_backupChecksStarted) return;
    final version = ++_backupReadVersion;
    _backupNeeded = null;
    _publish();
    if (_defaultKeys.isNotEmpty) {
      unawaited(_readPhysicalBackups(_defaultKeys));
    }
    final needed = await _readBackupWarning();
    if (_closed || version != _backupReadVersion) return;
    if (needed == null) log.warning('recoverbull.backup.status.unavailable');
    _backupNeeded = needed;
    _publish();
  }

  Future<void> _readPhysicalBackups(Set<WalletKey> defaults) async {
    final version = ++_physicalBackupVersion;
    final values = await Future.wait(
      defaults.map((key) async {
        try {
          return await _readPhysicalBackup(key);
        } on Exception {
          return null;
        }
      }),
    );
    if (_closed || version != _physicalBackupVersion) return;
    _physicalBackupNeeded = values.any((verified) => verified != true);
    _publish();
  }

  void _refreshSilent() {
    if (_closed) return;
    unawaited(
      _silentHome.refresh((update) {
        if (_closed) return;
        _silentVisible = update.visible ?? _silentVisible;
        _silentConfigured = update.configured ?? _silentConfigured;
        _silentBalanceSat = update.balanceSat ?? _silentBalanceSat;
        _silentLoading = update.loading;
        _publish();
      }),
    );
  }

  void _onSyncStarted(HomeSyncStart start) {
    if (_closed ||
        _status == OverviewCatalogueStatus.revoked ||
        _status == OverviewCatalogueStatus.replacing ||
        _status == OverviewCatalogueStatus.closed) {
      return;
    }
    _syncRuns[start.key] = start.runId;
    if (!_wallets.any((wallet) => wallet.entry.key == start.key)) return;
    if (_syncing.add(start.key)) _publish();
  }

  void _onSyncFinished(WalletKey key) {
    if (_closed) return;
    if (_status == OverviewCatalogueStatus.revoked ||
        _status == OverviewCatalogueStatus.replacing ||
        _status == OverviewCatalogueStatus.closed) {
      return;
    }
    if (!_wallets.any((wallet) => wallet.entry.key == key)) return;
    final changed = _syncing.remove(key);
    // A finished pass can change a swap's state and the backup answer even
    // when the balance stayed the same.
    unawaited(_readSwaps());
    unawaited(_verifyBackup());
    if (changed) _publish();
  }

  // A proxy wait on one chain must not discard a current outcome from the other.
  void _enqueueElectrumOutcome(HomeElectrumOutcome outcome) {
    _electrumUpdates = _electrumUpdates.then(
      (_) => _applyElectrumOutcome(outcome),
    );
    unawaited(_electrumUpdates);
  }

  bool _acceptsElectrumOutcome(HomeElectrumOutcome outcome) {
    return !_closed &&
        _status != OverviewCatalogueStatus.revoked &&
        _status != OverviewCatalogueStatus.replacing &&
        _status != OverviewCatalogueStatus.closed &&
        _wallets.any((wallet) => wallet.entry.key == outcome.key) &&
        _syncRuns[outcome.key] == outcome.runId;
  }

  Future<void> _applyElectrumOutcome(HomeElectrumOutcome outcome) async {
    if (!_acceptsElectrumOutcome(outcome)) return;
    final warnings = await _networkWarnings.update(
      isLiquid: outcome.isLiquid,
      success: outcome.success,
      isCurrent: () => _acceptsElectrumOutcome(outcome),
    );
    if (!_acceptsElectrumOutcome(outcome) || warnings == null) return;
    _warnings = warnings;
    _publish();
  }

  void _onSyncActivity(bool active) {
    if (_closed || _isSyncPassActive == active) return;
    _isSyncPassActive = active;
    _publish();
  }

  void _onAmountDisplay(AmountDisplayPreferences? preferences) {
    if (_closed) return;
    _amountPreferences = preferences;
    _publish();
  }

  void _updateSilent(OverviewHomeSnapshot snapshot) {
    switch (snapshot.status) {
      case OverviewCatalogueStatus.replacing ||
          OverviewCatalogueStatus.revoked ||
          OverviewCatalogueStatus.closed:
        if (!_silentRetired) {
          _silentRetired = true;
          _silentHome.catalogReplacing();
        }
        _publishedMembership = null;
        _silentVisible = false;
        _silentConfigured = false;
        _silentBalanceSat = 0;
        _silentLoading = false;
      case OverviewCatalogueStatus.ready ||
          OverviewCatalogueStatus.empty ||
          OverviewCatalogueStatus.partial ||
          OverviewCatalogueStatus.unreadable:
        _silentRetired = false;
        final membership = [
          for (final wallet in snapshot.wallets)
            '${wallet.entry.key.id}|${wallet.entry.key.network}',
        ]..sort();
        if (membership.join(',') == _publishedMembership) return;
        _publishedMembership = membership.join(',');
        _silentHome.catalogPublished({
          for (final wallet in snapshot.wallets) wallet.entry.key.network.env,
        });
        _refreshSilent();
    }
  }

  void _publish() {
    if (_closed) return;
    _state.value = OverviewHomeState(
      status: _status,
      rows: _rows(),
      totalSat: _total(),
      arkScope: _arkScope(),
      isRefreshing: _isRefreshing,
      isSyncPassActive: _isSyncPassActive,
      hideAmounts: _amountPreferences?.hideAmounts,
      networkWarnings: List.unmodifiable(_warnings),
      swapServerUnreachable: _swapServerUnreachable,
      loadFailure: _loadFailure(),
      ongoingSwaps: List.unmodifiable(_swaps),
      backupCard: (_backupNeeded ?? _physicalBackupNeeded) == true,
      backupWarning: _showBackupWarning(),
      silent: (
        visible: _silentVisible,
        configured: _silentConfigured,
        balanceSat: _silentBalanceSat,
        loading: _silentLoading,
      ),
    );
  }

  List<OverviewHomeRow> _rows() => List.unmodifiable([
    for (final wallet in _wallets)
      (
        selection: (
          key: wallet.entry.key,
          label: wallet.entry.label,
          isDefault: wallet.entry.isDefault,
        ),
        signer: wallet.entry.signer,
        origin: _origin(wallet.entry.key),
        balanceSat: wallet.balanceSat,
        isSyncing: _syncing.contains(wallet.entry.key),
      ),
  ]);

  /// Identity for display only: the same fallback `Wallet.displayLabel` used,
  /// with the regtest suffix stripped by its producer.
  static String _origin(WalletKey key) =>
      key.network.env == NetworkEnv.regtest && key.id.endsWith(':regtest')
      ? key.id.substring(0, key.id.length - ':regtest'.length)
      : key.id;

  int? _total() {
    if (_status == OverviewCatalogueStatus.partial ||
        _status == OverviewCatalogueStatus.unreadable) {
      return null;
    }
    var total = (_silentVisible && _silentConfigured) ? _silentBalanceSat : 0;
    for (final wallet in _wallets) {
      final balance = wallet.balanceSat;
      if (balance == null) return null;
      total += balance;
    }
    return total;
  }

  String _arkScope() => [
    for (final wallet in _wallets)
      if (wallet.entry.isDefault &&
          wallet.entry.key.network == BitcoinNetwork.regtest)
        (wallet.entry.key.id, wallet.entry.masterFingerprint?.hex ?? ''),
  ].toString();

  OverviewLoadFailure? _loadFailure() => switch (_status) {
    OverviewCatalogueStatus.unreadable => OverviewLoadFailure.loadFailed,
    // The list loaded in part; the missing rows are why a balance can lag.
    OverviewCatalogueStatus.partial => OverviewLoadFailure.balancesMayBeStale,
    _ => _syncFailure,
  };

  bool _showBackupWarning() =>
      (_backupNeeded ?? _physicalBackupNeeded) == true &&
      !_backupDismissed &&
      switch (_total()) {
        null => true,
        final total => total > 0,
      };
}
