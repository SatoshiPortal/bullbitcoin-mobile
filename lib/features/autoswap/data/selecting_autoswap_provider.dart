import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bull_swap/bull_swap.dart'
    show SwapProviderKind, SwapProviderStore;

class SelectingAutoswapProvider implements AutoswapProviderPort {
  final SwapProviderStore _store;
  final AutoswapProviderPort _bull;
  final AutoswapProviderPort _boltz;

  const SelectingAutoswapProvider(this._store, this._bull, this._boltz);

  @override
  Future<Result<String, AutoswapFailure>> execute(AutoSwap settings) async {
    final active = await _store.active();
    final provider = active?.kind == SwapProviderKind.boltz ? _boltz : _bull;
    return provider.execute(settings);
  }
}
