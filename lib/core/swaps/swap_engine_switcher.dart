import 'dart:async';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/switchable_swap_repository.dart';
import 'package:swaps/swaps.dart' show SwapWatcher;
import 'package:bull_logger/bull_logger.dart';

/// Rebuilds the swap engine when the network or the Boltz server changes,
/// so swaps never run against the network the app has just left. The
/// watcher is stopped across the swap and restarted on the new engine.
class SwapEngineSwitcher {
  final SettingsRepository _settingsRepository;
  final SwitchableSwapRepository _swapRepository;
  final SwapWatcher _swapWatcher;
  final Future<SwapEngineParts> Function({required bool isTestnet}) _build;

  StreamSubscription<Environment>? _environmentChanges;
  Future<void> _pending = Future.value();

  SwapEngineSwitcher({
    required this._settingsRepository,
    required this._swapRepository,
    required this._swapWatcher,
    required this._build,
  });

  void start() {
    _environmentChanges ??= _settingsRepository.environmentChangeStream.listen((
      environment,
    ) {
      final isTestnet = !environment.isMainnet;
      if (isTestnet == _swapRepository.isTestnet) return;
      unawaited(rebuild(isTestnet: isTestnet));
    });
  }

  /// Rebuilds the engine for [isTestnet], or for the current network when
  /// null. Rebuilds run one after another.
  Future<void> rebuild({bool? isTestnet}) {
    final next = _pending.then(
      (_) => _rebuild(isTestnet: isTestnet ?? _swapRepository.isTestnet),
    );
    _pending = next;
    return next;
  }

  Future<void> _rebuild({required bool isTestnet}) async {
    try {
      await _swapWatcher.stop();
      await _swapRepository.replace(await _build(isTestnet: isTestnet));
      log.config('[Swaps] engine rebuilt (isTestnet=$isTestnet)');
    } catch (e) {
      log.warning('[Swaps] engine rebuild failed (${e.runtimeType})');
    } finally {
      unawaited(_swapWatcher.start());
    }
  }

  Future<void> dispose() async {
    await _environmentChanges?.cancel();
    _environmentChanges = null;
  }
}
