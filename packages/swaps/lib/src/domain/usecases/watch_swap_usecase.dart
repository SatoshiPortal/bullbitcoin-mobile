import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/swap_store.dart';

class WatchSwapUsecase {
  final SwapStore _store;

  const WatchSwapUsecase(this._store);

  Stream<Swap> execute(String swapId) => _store.watch(swapId);
}
