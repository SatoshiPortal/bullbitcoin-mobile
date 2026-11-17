import 'dart:async';

import 'package:bb_mobile/features/wallet/data/ark_foreground_runtime.dart';
import 'package:bull_ark/ark_setup.dart' show ArkPreferencesRepository;
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/bull_ark.dart'
    show ArkFailure, ArkServiceUnavailableFailure;
import 'package:bull_logger/bull_logger.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

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
  ArkForegroundRuntime? _runtime;
  Future<Result<ArkForegroundRuntime, ArkFailure>>? _pending;
  int _generation = 0;
  bool _closed = false;

  ArkForegroundHost(
    this._locator, {
    required Uri arkUrl,
    required Uri primaryEsploraUrl,
    required bool initializeNew,
    this._preferences,
  }) : _ark = arkUrl,
       _esplora = primaryEsploraUrl,
       _initialize = initializeNew;

  /// Registers the host for an explicit regtest Ark profile and installs its
  /// custody references. Must run before seed deletion is reachable.
  static Future<void> setup(
    GetIt locator, {
    required Uri arkUrl,
    required Uri primaryEsploraUrl,
    required bool initializeNew,
  }) async {
    final host = ArkForegroundHost(
      locator,
      arkUrl: arkUrl,
      primaryEsploraUrl: primaryEsploraUrl,
      initializeNew: initializeNew,
    );
    locator.registerSingleton<ArkForegroundHost>(
      host,
      dispose: (value) => value.close(),
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
      log.warning('Ark custody references unavailable', error: failure);
    }
  }

  /// The runtime matching the current selection, opening one if needed.
  Future<Result<ArkForegroundRuntime, ArkFailure>> current() =>
      _pending ??= _current().whenComplete(() => _pending = null);

  /// Synchronously retires the current runtime and its mounted pages.
  ///
  /// Call when the app context Ark depends on changes, such as the active
  /// network. A runtime still opening is closed instead of published.
  void invalidate() {
    ++_generation;
    final runtime = _runtime;
    _runtime = null;
    if (runtime == null) return;
    runtime.invalidate();
    unawaited(
      runtime.close().catchError((Object error, StackTrace stack) {
        log.warning('Ark runtime close failed', error: error, trace: stack);
      }),
    );
  }

  Future<Result<ArkForegroundRuntime, ArkFailure>> _current() async {
    if (_closed) return const Err(ArkServiceUnavailableFailure());
    final generation = _generation;
    final existing = _runtime;
    if (existing != null) {
      if (await existing.isCurrent()) return Ok(existing);
      _runtime = null;
      existing.invalidate();
      await existing.close();
    }
    final opened = await openArkForeground(
      _locator,
      arkUrl: _ark,
      primaryEsploraUrl: _esplora,
      initializeNew: _initialize,
      preferences: _preferences,
    );
    if (opened case Ok(:final value)) {
      if (_closed || generation != _generation) {
        await value.close();
        return const Err(ArkServiceUnavailableFailure());
      }
      _runtime = value;
    }
    return opened;
  }

  Future<void> close() async {
    _closed = true;
    final pending = _pending;
    if (pending != null) await pending;
    final runtime = _runtime;
    _runtime = null;
    await runtime?.close();
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
          final unavailable = createArkUnavailableRoutes().first.builder!;
          if (snapshot.hasError) {
            log.warning('Ark runtime failed to open', error: snapshot.error);
            return unavailable(context, widget.state);
          }
          switch (snapshot.data) {
            case null:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            case Err(:final failure):
              log.warning('Ark runtime unavailable', error: failure);
              return unavailable(context, widget.state);
            case Ok(:final value):
              for (final route in value.feature.routes) {
                if (route.path == widget.path) {
                  return route.builder!(context, widget.state);
                }
              }
              return unavailable(context, widget.state);
          }
        },
      );
}
