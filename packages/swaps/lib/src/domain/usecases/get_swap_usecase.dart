import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_store.dart';

class GetSwapUsecase {
  final SwapStore _store;

  const GetSwapUsecase(this._store);

  Future<Result<Swap, SwapsFailure>> execute({required String swapId}) =>
      _store.get(swapId);
}
