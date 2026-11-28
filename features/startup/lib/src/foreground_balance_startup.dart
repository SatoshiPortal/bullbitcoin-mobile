import 'dart:async';

import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import 'balance_startup_probe.dart';

part 'foreground_balance_observation.dart';

typedef _Candidate = ({WalletCatalogueStamp catalogue, int environmentEpoch});
typedef _Revision = (WalletRevision, WalletLifecycle, int);

/// Owns the first and subsequent local balance demands, not the Sync owner.
final class ForegroundBalanceStartup {
  final WalletCatalogueSignal _catalogue;
  final ForegroundSession _session;
  final Stream<bool> _transitions;
  final bool Function() _environmentChanging;
  final Future<bool> Function()? _isUnprotected;
  final Future<NetworkEnv?> Function() _readEnvironment;
  final Future<Result<List<WalletKey>, SyncFailure>> Function(
    WalletCatalogueStamp,
  )
  _select;
  final Stream<WalletRevisionState> Function() _revisions;
  final RetainedBalanceDemand? Function(
    WalletKey,
    BalanceEnvironment? Function(), {
    WalletCatalogueStamp? catalogue,
  })
  _capture;
  final Future<Result<WalletRevision, SyncFailure>> Function(
    RetainedBalanceDemand,
  )
  _demand;
  final Result<BigInt, SyncFailure> Function(
    WalletCatalogueStamp,
    WalletRevision,
  )?
  _readRetained;

  final _changes = StreamController<void>.broadcast();
  late final observation = ForegroundBalanceObservation._(this);
  ForegroundBalanceContext? _context;
  final _subscriptions = <StreamSubscription<void>>[];
  final _keys = <WalletKey>{};
  final _queued = <WalletKey>{};
  final _seen = <WalletKey, _Revision>{};
  final _versions = <WalletKey, int>{};
  final _receipts = <WalletKey, ForegroundBalanceReceipt>{};
  final _probe = BalanceStartupProbe.enabled ? BalanceStartupProbe() : null;
  _Candidate? _candidate;
  BalanceEnvironment? _environment;
  var _environmentEpoch = 0;
  var _admitted = false;
  var _awaitingUnprotected = false;
  _Candidate? _unprotectedCandidate;
  var _selecting = false;
  var _ready = false;
  var _settled = false;
  var _disabled = false;
  Future<void>? _work;
  Future<void>? _checkingUnprotected;
  Future<void>? _disposing;

  factory ForegroundBalanceStartup.mount({
    required WalletNativeRuntime Function() runtime,
    required SecretsInventory inventory,
    required Preferences preferences,
  }) {
    final catalog = SecretsWalletCatalog.foreground(inventory);
    return ForegroundBalanceStartup.testing(
      catalogue: inventory.walletCatalogue,
      session: inventory.foregroundSession,
      transitions: preferences.environmentTransitions,
      environmentChanging: () => preferences.isEnvironmentChanging,
      isUnprotected: () async =>
          (await inventory.isProtected()).fold((value) => !value, (_) => false),
      readEnvironment: () async => (await preferences.readActiveEnvironment())
          .fold((value) => value.networkEnv, (_) => null),
      select: (stamp) async {
        final bound = catalog.bindWalletCatalogue(stamp);
        if (bound == null) return const Err(SyncClosedFailure());
        return (await bound.list()).map(
          (descriptors) => descriptors.map((value) => value.key).toList(),
        );
      },
      revisions: () => runtime().changes,
      capture: (key, environment, {catalogue}) => runtime()
          .captureBalanceDemand(key, environment, catalogue: catalogue),
      demand: (request) => runtime().demandRetainedBalance(request),
      readRetained: (catalogue, revision) =>
          runtime().readRetainedBalance(catalogue, revision),
    );
  }

  @visibleForTesting
  ForegroundBalanceStartup.testing({
    required this._catalogue,
    required this._session,
    required this._transitions,
    required this._environmentChanging,
    this._isUnprotected,
    required this._readEnvironment,
    required this._select,
    required this._revisions,
    required this._capture,
    required this._demand,
    this._readRetained,
  });

  /// Called by the accepted PIN continuation (or the explicit no-PIN path).
  /// Arm and capture before starting or waiting for anything.
  void admitUnlock() {
    if (_disabled) return;
    if (_subscriptions.isEmpty) {
      _probe?.arm();
      _subscriptions.addAll([
        _session.changes.listen((token) {
          if (token == null) {
            revokeUnlock();
          } else if (_awaitingUnprotected) {
            _awaitingUnprotected = false;
            _considerUnprotected(token);
          } else {
            _schedule();
          }
        }),
        _catalogue.changes.listen((_) => _schedule()),
        _transitions.listen((changing) {
          if (changing) {
            _environmentEpoch++;
            _retire();
            _probe?.invalidate();
          } else {
            _schedule();
          }
        }),
        _revisions().listen(_onRevision),
      ]);
    }
    if (_session.capture() == null) {
      // Access can finish the no-PIN route before its automatic reopen has
      // finished draining. Do not treat the next protected grant as success.
      _awaitingUnprotected = true;
      return;
    }
    _awaitingUnprotected = false;
    _unprotectedCandidate = null;
    _admitted = true;
    _schedule();
  }

  void revokeUnlock() {
    _admitted = false;
    _awaitingUnprotected = false;
    _unprotectedCandidate = null;
    _retire();
    _probe?.invalidate();
  }

  void _considerUnprotected(SessionToken token) {
    final check = _isUnprotected;
    if (_disabled || check == null) return;
    final stamp = _catalogue.capture();
    if (stamp == null || !identical(stamp.grant, token)) return;
    _unprotectedCandidate = (
      catalogue: stamp,
      environmentEpoch: _environmentEpoch,
    );
    if (_checkingUnprotected != null) return;
    _checkingUnprotected = Future<void>.microtask(() async {
      try {
        while (!_disabled) {
          final captured = _unprotectedCandidate;
          if (captured == null) return;
          final accepted =
              _session.isCurrent(captured.catalogue.grant) && await check();
          if (!identical(captured, _unprotectedCandidate)) continue;
          _unprotectedCandidate = null;
          if (accepted &&
              !_disabled &&
              _session.isCurrent(captured.catalogue.grant)) {
            _admitted = true;
            if (!_environmentChanging() &&
                captured.environmentEpoch == _environmentEpoch &&
                _catalogue.isCurrent(captured.catalogue)) {
              _install(captured);
            }
          }
        }
      } finally {
        _checkingUnprotected = null;
      }
    });
  }

  void initialized(Result<void, SyncFailure> result) {
    if (_disabled || _settled) return;
    _probe?.initialized(result is Ok);
    _settled = true;
    _ready = result is Ok;
    _wake();
  }

  void _retire() {
    final hadContext = _context != null;
    _context = null;
    _candidate = null;
    _environment = null;
    _selecting = false;
    _keys.clear();
    _queued.clear();
    _seen.clear();
    _versions.clear();
    _receipts.clear();
    if (hadContext) _changes.add(null);
  }

  void _schedule() {
    if (_disabled || _environmentChanging()) return;
    if (!_admitted) {
      if (_unprotectedCandidate case final pending?) {
        _considerUnprotected(pending.catalogue.grant);
      }
      return;
    }
    final stamp = _catalogue.capture();
    if (stamp == null) return;
    final previous = _candidate;
    if (previous != null &&
        previous.environmentEpoch == _environmentEpoch &&
        identical(previous.catalogue.grant, stamp.grant) &&
        previous.catalogue.generation == stamp.generation) {
      return;
    }
    _install((catalogue: stamp, environmentEpoch: _environmentEpoch));
  }

  void _install(_Candidate candidate) {
    _retire();
    _candidate = candidate;
    _selecting = true;
    _wake();
  }

  bool _current(_Candidate candidate) =>
      !_disabled &&
      _admitted &&
      identical(_candidate, candidate) &&
      !_environmentChanging() &&
      _catalogue.isCurrent(candidate.catalogue);

  void _onRevision(WalletRevisionState state) {
    final candidate = _candidate;
    final key = state.stamp.key;
    if (candidate == null || !_current(candidate) || !_keys.contains(key)) {
      return;
    }
    final revision = (state.stamp, state.lifecycle, state.initializedSchema);
    final previous = _seen[key];
    if (previous == revision) return;
    _seen[key] = revision;
    // A first notification for a completed stamp is not new work. A
    // pending-to-active transition at that same stamp is new work.
    if (previous == null &&
        state.lifecycle == WalletLifecycle.active &&
        _receipts[key]?.revision == state.stamp) {
      return;
    }
    _versions.update(key, (version) => version + 1, ifAbsent: () => 1);
    if (_receipts.remove(key) != null) _changes.add(null);
    if (state.lifecycle == WalletLifecycle.active) {
      _queued.add(key);
      _wake();
    } else {
      _queued.remove(key);
    }
  }

  void _wake() {
    final candidate = _candidate;
    if (candidate == null ||
        !_current(candidate) ||
        !_settled ||
        _work != null ||
        (!_selecting && _queued.isEmpty)) {
      return;
    }
    _work = Future<void>.microtask(() async {
      try {
        await _drain();
      } finally {
        _work = null;
        _wake();
      }
    });
  }

  Future<void> _drain() async {
    while (true) {
      final candidate = _candidate;
      if (candidate == null || !_current(candidate)) return;
      if (_selecting) {
        _selecting = false;
        // The epoch was captured in the notification, before an older
        // candidate could drain. Never adopt a read spanning a transition.
        final environment = await _readEnvironment();
        if (!_current(candidate)) continue;
        _context = ForegroundBalanceContext._(environment, candidate);
        _changes.add(null);
        if (environment == null || !_ready) continue;
        final selection = await _select(candidate.catalogue);
        if (!_current(candidate)) continue;
        if (selection case Ok(:final value)) {
          _environment = (
            environment: environment,
            epoch: candidate.environmentEpoch,
          );
          _keys.addAll(value.where((key) => key.network.env == environment));
          _queued.addAll(_keys);
        }
      }
      if (_queued.isEmpty) return;
      final key = _queued.first;
      _queued.remove(key);
      final version = _versions[key];
      BalanceEnvironment? environment() =>
          _current(candidate) && _versions[key] == version
          ? _environment
          : null;
      final demand = _capture(key, environment, catalogue: candidate.catalogue);
      if (demand == null) continue;
      if (_probe case final probe?) await probe.beforeDemand();
      if (!demand.isCurrent) continue;
      _probe?.attempt();
      final result = await _demand(demand);
      if (!demand.isCurrent) continue;
      if (result case Ok(:final value) when value.key == key) {
        final context = _context;
        if (context != null) {
          _receipts[key] = ForegroundBalanceReceipt._(context, value);
          _changes.add(null);
        }
      }
      _probe?.completed(result is Ok, liquid: key.network is LiquidNetwork);
    }
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disabled = true;
    _unprotectedCandidate = null;
    _retire();
    _probe?.release();
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await _checkingUnprotected;
    await _work;
    unawaited(_changes.close());
  }
}
