import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/boltz_swaps.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/entities/swap_master_key_info.dart';

/// The rescue key of the default Bitcoin wallet, for the seed viewer.
class GetSwapMasterKeyUsecase {
  final BoltzSwaps _boltz;

  const GetSwapMasterKeyUsecase(this._boltz);

  Future<Result<SwapMasterKeyInfo?, SwapsFailure>> execute() =>
      _boltz.masterKeyInfo();
}
