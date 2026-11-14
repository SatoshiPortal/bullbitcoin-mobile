import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';

/// Deletes the default Bitcoin wallet's rescue key.
class DeleteSwapMasterKeyUsecase {
  final BoltzSwaps _boltz;

  const DeleteSwapMasterKeyUsecase(this._boltz);

  Future<Result<void, SwapsFailure>> execute() => _boltz.deleteMasterKey();
}
