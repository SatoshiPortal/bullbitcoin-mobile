import 'package:all_seed_view/src/domain/all_seed_view_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

class GetSwapMasterKeyUsecase {
  final BoltzSwaps _swaps;

  const GetSwapMasterKeyUsecase(this._swaps);

  @useResult
  Future<Result<SwapMasterKeyInfo?, AllSeedViewFailure>> execute() async =>
      (await _swaps.masterKeyInfo()).mapErr(
        (_) => const AllSeedViewFetchFailure(),
      );
}
