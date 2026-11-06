import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_payments_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Reveal a fresh taproot receive address to hand out to a payer.
///
/// Each call derives the next never-before-issued address (advancing the
/// receive tip), so the same address is never handed to two payers. Invoke
/// only on an explicit user "generate" action.
class GenerateTaprootAddressUsecase {
  final GetSpFeatureGateUsecase? _getSpFeatureGateUsecase;
  final SpPaymentsPort _repository;

  GenerateTaprootAddressUsecase({
    this._getSpFeatureGateUsecase,
    required this._repository,
  });

  @useResult
  Future<Result<String, SpFailure>> execute() async {
    if (await _getSpFeatureGateUsecase?.execute() != true) {
      return const Err(SpUnsupportedNetwork());
    }
    return _repository.generateTaprootAddress();
  }
}
