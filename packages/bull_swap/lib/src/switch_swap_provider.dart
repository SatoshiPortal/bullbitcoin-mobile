import 'package:bull_swap/src/data/swap_provider_resolver.dart';
import 'package:bull_swap/src/data/swap_provider_store.dart';
import 'package:bull_swap/src/domain/pending_swaps_probe.dart';
import 'package:bull_swap/src/domain/swap_failure.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';
import 'package:primitives/primitives.dart';

class SwitchSwapProvider {
  final SwapProviderStore _store;
  final PendingSwapsProbe _probe;
  final SwapProviderResolver _resolver;

  SwitchSwapProvider(this._store, this._probe, this._resolver);

  Future<Result<SwapProviderConfig, SwapFailure>> call(
    String providerId,
  ) async {
    if (await _probe.hasActiveSwaps()) {
      return const Err(
        SwapSwitchBlockedFailure('Cannot switch provider mid-swap'),
      );
    }
    final target = await _store.byId(providerId);
    if (target == null) {
      return const Err(SwapProviderMisconfiguredFailure('Unknown provider'));
    }
    if (!target.isConfigured) {
      return const Err(SwapProviderMisconfiguredFailure('Missing server URL'));
    }
    await _store.setActive(providerId);
    _resolver.invalidate();
    return Ok(target);
  }
}
