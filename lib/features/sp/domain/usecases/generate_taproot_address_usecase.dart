import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Reveal a fresh taproot receive address to hand out to a payer.
///
/// Each call derives the next never-before-issued address (advancing the
/// receive tip), so the same address is never handed to two payers. Invoke
/// only on an explicit user "generate" action.
class GenerateTaprootAddressUsecase {
  final SpAccountRepository _repository;

  GenerateTaprootAddressUsecase({required this._repository});

  @useResult
  Future<Result<String, SpFailure>> execute() =>
      _repository.generateTaprootAddress();
}
