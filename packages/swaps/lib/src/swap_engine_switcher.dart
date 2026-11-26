import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';

import 'domain/entities/swap_failure.dart';
import 'domain/swap_watcher.dart';
import 'switchable_swap_engine.dart';

/// Serializes replacement while retaining the latest requested network and
/// ownership of any work still draining after a Busy response.
class SwapEngineSwitcher {
  final Preferences _settingsRepository;
  final SwitchableSwapEngine _engine;
  final SwapWatcher _swapWatcher;
  final Future<SwapEngineParts> Function({required NetworkEnv environment})
  _build;
  final Duration _requestBudget;

  StreamSubscription<Environment>? _environmentChanges;
  Future<void> _pending = Future.value();
  late NetworkEnv _desiredEnvironment;
  int _revision = 0;
  bool _failed = false;
  bool _disposed = false;
  bool _sessionSuspended = false;
  Future<void>? _sessionStop;

  SwapEngineSwitcher({
    required this._settingsRepository,
    required this._engine,
    required this._swapWatcher,
    required this._build,
    this._requestBudget = const Duration(milliseconds: 100),
  }) {
    _desiredEnvironment = _engine.environment;
  }

  void start() {
    if (_disposed) return;
    _environmentChanges ??= _settingsRepository.environmentChangeStream
        .expand<Environment>(
          (result) => result.fold((value) => [value], (_) => const []),
        )
        .listen((environment) {
          final target = environment.networkEnv;
          if (target == _desiredEnvironment && !_failed) return;
          unawaited(rebuild(environment: target).then<void>((_) {}));
        });
  }

  /// Ok means activated. Busy retains the serialized transition; callers must
  /// not infer that a previous driver has closed or install another one.
  Future<Result<void, SwapsFailure>> rebuild({
    NetworkEnv? environment,
    bool waitForCompletion = false,
  }) {
    if (_disposed) return Future.value(const Err(SwapsBusyFailure()));
    final target = environment ?? _desiredEnvironment;
    _desiredEnvironment = target;
    final revision = ++_revision;
    _failed = false;
    _engine.suspendCreation();
    _swapWatcher.suspend();
    final work = _pending.then((_) => _rebuild(target, revision));
    _pending = work.then<void>((_) {});
    if (waitForCompletion) return work;
    return Future.any([
      work,
      Future<Result<void, SwapsFailure>>.delayed(
        _requestBudget,
        () => const Err(SwapsBusyFailure()),
      ),
    ]);
  }

  bool _current(int revision) => !_disposed && revision == _revision;

  Future<Result<void, SwapsFailure>> _rebuild(
    NetworkEnv target,
    int revision,
  ) async {
    SwapEngineParts? uninstalled;
    try {
      if (!_current(revision)) return const Err(SwapsBusyFailure());
      await _swapWatcher.stop();
      await _swapWatcher.drained;
      if (!_current(revision)) return const Err(SwapsBusyFailure());
      final parts = await _build(environment: target);
      uninstalled = parts;
      if (!_current(revision)) {
        await parts.boltz.close();
        return const Err(SwapsBusyFailure());
      }
      await _engine.replace(parts);
      uninstalled = null;
      if (!_current(revision)) return const Err(SwapsBusyFailure());
      // A locked session leaves the new engine installed but stopped; the
      // unlock starts it.
      if (_sessionSuspended) return const Err(SwapsBusyFailure());
      await _swapWatcher.start();
      if (!_current(revision)) {
        _swapWatcher.suspend();
        return const Err(SwapsBusyFailure());
      }
      if (!_swapWatcher.isRunning) {
        throw const SwapsBusyFailure('swap driver did not activate');
      }
      _engine.resumeCreation();
      log.config('[Swaps] engine rebuilt (network=${target.name})');
      return const Ok(null);
    } catch (error) {
      if (uninstalled case final parts?) await parts.boltz.close();
      _swapWatcher.suspend();
      if (_current(revision)) _failed = true;
      log.warning('[Swaps] engine rebuild failed (${error.runtimeType})');
      return Err(classifySwapsFailure(error));
    }
  }

  /// Revokes the swap driver for a locked session: creation and effects are
  /// refused at once, and no rebuild starts the driver again. Completes once
  /// the driver, any rebuild and any creation under way have all drained; it
  /// never completes on a timeout, so a late stop is still awaited.
  Future<void> suspendSession() {
    _sessionSuspended = true;
    _engine.suspendCreation();
    _engine.suspendEffects();
    _swapWatcher.suspend();
    return _sessionStop ??= _stopSession();
  }

  Future<void> _stopSession() async {
    try {
      unawaited(_swapWatcher.stop());
      await _swapWatcher.drained;
      await _pending;
      await _engine.creationsSettled;
      await _engine.effectsSettled;
    } finally {
      _sessionStop = null;
    }
  }

  /// Starts the driver again once, after a confirmed stop. Does nothing while
  /// the stop is still pending.
  void resumeSession() {
    if (!_sessionSuspended || _sessionStop != null) return;
    _sessionSuspended = false;
    if (_disposed || _failed) return;
    _engine.resumeCreation();
    _engine.resumeEffects();
    unawaited(_swapWatcher.start());
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_revision;
    _engine.suspendCreation();
    _swapWatcher.suspend();
    await _environmentChanges?.cancel();
    _environmentChanges = null;
    await _swapWatcher.stop();
    await _swapWatcher.drained;
    await _pending;
    await _engine.close();
  }
}
