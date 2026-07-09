import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

part 'proof_of_funds_state.freezed.dart';

enum ProofOfFundsStatus { idle, working, success, error }

@freezed
abstract class ProofOfFundsState with _$ProofOfFundsState {
  const factory ProofOfFundsState({
    required String walletId,
    @Default(ProofOfFundsStatus.idle) ProofOfFundsStatus status,

    /// The produced `pof` signature (prove flow), once generated.
    String? signature,

    /// The verification outcome (verify flow), once run.
    ProofResult? result,
    CoinsError? error,
  }) = _ProofOfFundsState;

  const ProofOfFundsState._();

  bool get isWorking => status == ProofOfFundsStatus.working;
}
