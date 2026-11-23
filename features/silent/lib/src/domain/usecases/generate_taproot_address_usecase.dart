import 'package:bull_logger/bull_logger.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/ports/sp_payments_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';

/// Reveal a fresh taproot receive address to hand out to a payer.
///
/// Each call derives the next never-before-issued address (advancing the
/// receive tip), so the same address is never handed to two payers. Invoke
/// only on an explicit user "generate" action.
class GenerateTaprootAddressUsecase {
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final SpPaymentsPort _repository;

  GenerateTaprootAddressUsecase({
    required this._getSpFeatureGateUsecase,
    required this._repository,
  });

  @useResult
  Future<Result<String, SilentFailure>> execute() async {
    if (!await _getSpFeatureGateUsecase.execute()) {
      log.warning('Capability refused feature=sp_receive reason=unsupported');
      return const Err(SilentUnsupportedNetwork());
    }
    return _repository.generateTaprootAddress();
  }
}
