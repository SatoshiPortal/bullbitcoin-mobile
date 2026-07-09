import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

part 'verify_proof_of_funds_state.freezed.dart';

enum VerifyProofOfFundsStatus { idle, working, success, error }

@freezed
abstract class VerifyProofOfFundsState with _$VerifyProofOfFundsState {
  const factory VerifyProofOfFundsState({
    @Default(VerifyProofOfFundsStatus.idle) VerifyProofOfFundsStatus status,
    ProofResult? result,
    CoinsError? error,
  }) = _VerifyProofOfFundsState;

  const VerifyProofOfFundsState._();

  bool get isWorking => status == VerifyProofOfFundsStatus.working;
}
