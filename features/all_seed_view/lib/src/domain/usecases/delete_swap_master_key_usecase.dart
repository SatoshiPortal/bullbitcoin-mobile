import 'package:all_seed_view/src/domain/all_seed_view_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

class DeleteSwapMasterKeyUsecase {
  final BoltzSwaps _swaps;

  const DeleteSwapMasterKeyUsecase(this._swaps);

  @useResult
  Future<Result<void, AllSeedViewFailure>> execute(
    SwapMasterKeyInfo key,
  ) async =>
      (await _swaps.deleteMasterKey(key))
          .mapErr((_) => const AllSeedViewDeleteFailure());
}
