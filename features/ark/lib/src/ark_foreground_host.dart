import 'dart:async';

import 'package:background_tasks/background_tasks.dart';
import 'package:ark/ark.dart' show ArkSnapshot;

import 'ark_app_services.dart';
import 'ark_foreground_runtime.dart';
import 'ui/ark_payment_scanner.dart';

import 'package:secrets/secrets.dart';
import 'package:bull_ark/ark_setup.dart' show ArkPreferencesRepository;
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/bull_ark.dart'
    show
        ArkAccountsFacade,
        ArkFailure,
        ArkServiceUnavailableFailure,
        ArkTransferFacade;
import 'package:bull_logger/bull_logger.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every route path the Ark feature composes; the host serves these only.
const arkHostPaths = [
  '/ark',
  '/ark/account',
  '/ark/pay',
  '/ark/receive',
  '/ark/vtxos',
  '/ark/info',
  '/ark/exits',
  '/ark/review',
  '/ark/unavailable',
  '/ark/claim-recovery',
  '/ark/board',
  '/ark/exit-request',
];

/// Root composition of the foreground Ark runtime for an admitted profile.
///
/// The runtime is opened on first navigation and replaced when the selected
/// wallet, network or endpoint no longer matches it.
final class ArkForegroundHost {
  final GetIt _locator;
  final Uri _ark;
  final Uri _esplora;
  final bool _initialize;
  final ArkPreferencesRepository? _preferences;
  final ArkScanner? _scanner;

  /// What only the app can give Ark, passed to each runtime it opens.
  final ArkAppServices _services;
  final BackgroundTaskDispatcher? dispatcher;
  final ArkBoardFundingBinding Function() _boardFunding;
  final WalletInventory _inventory;
  ArkForegroundRuntime? _runtime;
  Future<Result<ArkForegroundRuntime, ArkFailure>>? _pending;
  int _pendingGeneration = 0;
  final _retired = <Future<(Object, StackTrace)?>>{};
  (Object, StackTrace)? _closeFailure;
  int _generation = 0;
  bool _closed = false;
  bool _suspended = false;

  final _homeChanges = StreamController<void>.broadcast();
  StreamSubscription<Object?>? _watching;

  /// Fires when what home shows may have changed: a runtime opened or went
  /// away, or the open account published a new observation. Home reads
  /// [homeObservation] again then, instead of waiting for a navigation.
  Stream<void> get homeChanges => _homeChanges.stream;

  void _homeChanged() {
    if (!_homeChanges.isClosed) _homeChanges.add(null);
  }

  void _watch(ArkForegroundRuntime? runtime) {
    unawaited(_watching?.cancel());
    _watching = runtime?.feature.facade
        .watch(runtime.account)
        .listen((_) => _homeChanged());
    _homeChanged();
  }

  ArkForegroundHost(
    this._locator, {
    required Uri arkUrl,
    required Uri primaryEsploraUrl,
    required bool initializeNew,
    required this._boardFunding,
    required this._inventory,
    this._preferences,
    this._scanner,
    this.dispatcher,
    this._services = const ArkAppServices(),
  }) : _ark = arkUrl,
       _esplora = primaryEsploraUrl,
       _initialize = initializeNew;

  /// Registers the host for an explicit regtest Ark profile and installs its
  /// custody references. Must run before seed deletion is reachable.
  ///
  /// Each opened runtime gets its own Board funding factory, bound once to
  /// that runtime's client over the app-wide funding authority.
  static Future<void> setup(
    GetIt locator, {
    required Uri arkUrl,
    required Uri primaryEsploraUrl,
    required bool initializeNew,
    required WalletInventory inventory,
    required ArkBoardFundingBinding Function() boardFunding,
    ArkPreferencesRepository? preferences,
    BackgroundTaskDispatcher? dispatcher,
    ArkScanner? scanner,
    ArkAppServices services = const ArkAppServices(),
  }) async {
    final host = ArkForegroundHost(
      locator,
      arkUrl: arkUrl,
      primaryEsploraUrl: primaryEsploraUrl,
      initializeNew: initializeNew,
      preferences: preferences,
      scanner: scanner ?? scanArkPayment,
      services: services,
      boardFunding: boardFunding,
      inventory: inventory,
      dispatcher: dispatcher,
    );
    locator.registerSingleton<ArkForegroundHost>(
      host,
      dispose: (value) => value.close(),
    );
    locator.registerSingleton<ArkTransferFacade>(
      ArkTransferFacade(() async {
        return switch (await host.current()) {
          Err(:final failure) => Err(failure),
          Ok(:final value) => value.transferContext(),
        };
      }),
    );
    locator.registerSingleton<ArkAccountsFacade>(
      ArkAccountsFacade((network) async {
        return switch (await host.current()) {
          Err(:final failure) => Err(failure),
          Ok(:final value) => value.feature.facade.listEnabledAccounts(network),
        };
      }),
    );
    await host.prepare();
  }

  /// Installs the fail-closed custody reference owner.
  Future<void> prepare() async {
    final result = await prepareArkCustodyReferences(
      _locator,
      initializeNew: _initialize,
    );
    if (result case Err(:final failure)) {
      log.warning('Ark custody references unavailable: ${failure.runtimeType}');
      return;
    }
    final dispatcher = this.dispatcher;
    if (dispatcher != null &&
        await prepareArkMaintenanceSchedule(_locator, dispatcher)) {
      await current();
    }
  }

  /// The runtime matching the current selection, opening one if needed.
  ///
  /// A new runtime is opened only after every retired runtime has drained.
  Future<Result<ArkForegroundRuntime, ArkFailure>> current() {
    final pending = _pending;
    if (pending != null && _pendingGeneration == _generation) return pending;
    final generation = _generation;
    late final Future<Result<ArkForegroundRuntime, ArkFailure>> next;
    next =
        () async {
          // An invalidated open must finish before the next one starts.
          if (pending != null) {
            try {
              await pending;
            } catch (_) {
              // Its own caller observes that failure.
            }
          }
          return _current(generation);
        }().whenComplete(() {
          if (identical(_pending, next)) _pending = null;
        });
    _pending = next;
    _pendingGeneration = generation;
    return next;
  }

  /// Renew when the app returns to the foreground, if a runtime is open.
  Future<void> resume() async {
    final runtime = _runtime;
    if (!_closed && !_suspended && runtime != null) await runtime.maintain();
  }

  /// Read only an already-open account. Home never initializes a runtime.
  Future<ArkSnapshot?> homeObservation() async {
    final runtime = _runtime;
    final generation = _generation;
    bool live() =>
        !_closed && generation == _generation && identical(runtime, _runtime);
    if (runtime == null || _pending != null || !live()) return null;
    if (!await runtime.isCurrent() || !live()) return null;
    final result = await runtime.feature.facade.read(runtime.account);
    if (!live() || !await runtime.isCurrent() || !live()) return null;
    // An out-of-date observation of this account is still its balance, as
    // other wallets show theirs while they sync; the card marks it so.
    return switch (result) {
      Ok(:final value) when value.account == runtime.account => value,
      _ => null,
    };
  }

  static const _homeBalanceKey = 'ark_home_balance';

  /// The balance home last showed for [scope], to show while Ark opens
  /// instead of nothing; null when home never showed one.
  Future<Sats?> lastHomeBalance(String scope) async {
    try {
      final stored = await SharedPreferencesAsync().getString(
        '$_homeBalanceKey:$scope',
      );
      final value = stored == null ? null : BigInt.tryParse(stored);
      return value == null || value.isNegative ? null : Sats(value);
    } on Exception {
      return null;
    }
  }

  /// Remembers what home shows for [scope], for the next cold start.
  Future<void> rememberHomeBalance(String scope, Sats balance) async {
    try {
      await SharedPreferencesAsync().setString(
        '$_homeBalanceKey:$scope',
        balance.value.toString(),
      );
    } on Exception {
      // Only a faster first paint is lost.
    }
  }

  /// Synchronously retires the current runtime and its mounted pages.
  ///
  /// Call before or when the app context Ark depends on changes, such as the
  /// active network. A runtime still opening is closed instead of published.
  void invalidate() {
    ++_generation;
    final runtime = _runtime;
    _runtime = null;
    _watch(null);
    if (runtime != null) _retire(runtime);
  }

  /// Invalidates [runtime] and records its close until it has drained.
  ///
  /// The close always starts, even if invalidation throws; that error is
  /// reported as the close failure.
  void _retire(ArkForegroundRuntime runtime) {
    (Object, StackTrace)? invalidation;
    try {
      runtime.invalidate();
    } catch (error, stack) {
      invalidation = (error, stack);
    }
    _retired.add(
      runtime.close().then<(Object, StackTrace)?>(
        (_) => invalidation,
        onError: (Object error, StackTrace stack) =>
            invalidation ?? (error, stack),
      ),
    );
  }

  /// Waits for every retired runtime. The first close failure is kept: the
  /// host then refuses to open another runtime and close rethrows it.
  Future<(Object, StackTrace)?> _drain() async {
    while (_retired.isNotEmpty) {
      final batch = List.of(_retired);
      final results = await Future.wait(batch);
      _retired.removeAll(batch);
      for (final failure in results) {
        if (failure == null) continue;
        log.warning('Ark runtime close failed: ${failure.$1.runtimeType}');
        _closeFailure ??= failure;
      }
    }
    return _closeFailure;
  }

  Future<Result<ArkForegroundRuntime, ArkFailure>> _current(
    int generation,
  ) async {
    if (_closed || _suspended || generation != _generation) {
      return const Err(ArkServiceUnavailableFailure());
    }
    final existing = _runtime;
    if (existing != null) {
      if (await existing.isCurrent()) return Ok(existing);
      if (identical(_runtime, existing)) {
        _runtime = null;
        _retire(existing);
      }
    }
    // The replacement opens the same storage: the retired client goes first.
    if (await _drain() != null) {
      return const Err(ArkServiceUnavailableFailure());
    }
    if (_closed || _suspended || generation != _generation) {
      return const Err(ArkServiceUnavailableFailure());
    }
    final opened = await openArkForeground(
      _locator,
      arkUrl: _ark,
      primaryEsploraUrl: _esplora,
      initializeNew: _initialize,
      boardFunding: _boardFunding(),
      inventory: _inventory,
      preferences: _preferences,
      dispatcher: dispatcher,
      scanner: _scanner,
      services: _services,
    );
    if (opened case Ok(:final value)) {
      if (_closed || _suspended || generation != _generation) {
        _retire(value);
        return const Err(ArkServiceUnavailableFailure());
      }
      _runtime = value;
      _watch(value);
    }
    return opened;
  }

  /// Revokes the runtime now: it retires synchronously and nothing opens until
  /// [reopen]. Completes once every retired runtime has drained, so the native
  /// writer is confirmed closed; a close failure rethrows and, as for [close],
  /// the host then refuses to open another runtime.
  Future<void> suspend() async {
    _suspended = true;
    invalidate();
    final pending = _pending;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Its own caller observes that failure.
      }
    }
    final failure = await _drain();
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
  }

  /// Lets the next navigation open a runtime again. Opens nothing itself.
  void reopen() {
    if (!_suspended) return;
    _suspended = false;
    _homeChanged();
  }

  /// Closes the current, opening and retired runtimes; rethrows the first
  /// close failure after all of them have drained.
  Future<void> close() async {
    _closed = true;
    ++_generation;
    Object? openError;
    StackTrace? openTrace;
    final pending = _pending;
    if (pending != null) {
      try {
        await pending;
      } catch (error, stack) {
        openError = error;
        openTrace = stack;
      }
    }
    final runtime = _runtime;
    _runtime = null;
    await _watching?.cancel();
    _watching = null;
    await _homeChanges.close();
    if (runtime != null) _retire(runtime);
    final failure = await _drain();
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
    if (openError != null && openTrace != null) {
      Error.throwWithStackTrace(openError, openTrace);
    }
  }

  /// Routes that delegate to the current runtime's feature routes.
  List<GoRoute> get routes => [
    for (final path in arkHostPaths)
      GoRoute(
        path: path,
        builder: (_, state) => _ArkHostPage(
          key: state.pageKey,
          host: this,
          path: path,
          state: state,
        ),
      ),
  ];
}

class _ArkHostPage extends StatefulWidget {
  final ArkForegroundHost host;
  final String path;
  final GoRouterState state;
  const _ArkHostPage({
    super.key,
    required this.host,
    required this.path,
    required this.state,
  });

  @override
  State<_ArkHostPage> createState() => _ArkHostPageState();
}

class _ArkHostPageState extends State<_ArkHostPage> {
  late final Future<Result<ArkForegroundRuntime, ArkFailure>> _runtime = widget
      .host
      .current();

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Result<ArkForegroundRuntime, ArkFailure>>(
        future: _runtime,
        builder: (context, snapshot) {
          final unavailable = createArkUnavailableRoutes().first.builder;
          if (unavailable == null) {
            throw StateError('Ark unavailable route has no builder');
          }
          if (snapshot.hasError) {
            log.warning(
              'Ark runtime failed to open: ${snapshot.error.runtimeType}',
            );
            return unavailable(context, widget.state);
          }
          switch (snapshot.data) {
            case null:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case Err(:final failure):
              log.warning('Ark runtime unavailable: ${failure.runtimeType}');
              return unavailable(context, widget.state);
            case Ok(:final value):
              for (final route in value.feature.routes) {
                final builder = route.builder;
                if (route.path == widget.path && builder != null) {
                  return builder(context, widget.state);
                }
              }
              return unavailable(context, widget.state);
          }
        },
      );
}
