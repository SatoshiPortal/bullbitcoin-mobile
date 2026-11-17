import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_store.dart';

class GetSwapsUsecase {
  final SwapStore _store;

  const GetSwapsUsecase(this._store);

  Future<Result<List<Swap>, SwapsFailure>> execute({String? walletId}) =>
      _store.all(walletId: walletId);
}
