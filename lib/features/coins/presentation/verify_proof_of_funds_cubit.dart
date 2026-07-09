import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:bb_mobile/features/coins/domain/usecases/verify_proof_of_funds_usecase.dart';
import 'package:bb_mobile/features/coins/presentation/verify_proof_of_funds_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the standalone "verify a proof of funds" flow (e.g. from Settings).
/// Network-agnostic: the use-case resolves the network from the app
/// environment, so no wallet is required to verify someone else's proof.
class VerifyProofOfFundsCubit extends Cubit<VerifyProofOfFundsState> {
  VerifyProofOfFundsCubit({required this.verifyProofOfFundsUsecase})
    : super(const VerifyProofOfFundsState());

  final VerifyProofOfFundsUsecase verifyProofOfFundsUsecase;

  Future<void> verify({
    required String message,
    required String challengeAddress,
    required String signature,
  }) async {
    emit(
      state.copyWith(
        status: VerifyProofOfFundsStatus.working,
        error: null,
        result: null,
      ),
    );
    try {
      final result = await verifyProofOfFundsUsecase.execute(
        message: message,
        challengeAddress: challengeAddress,
        signature: signature,
      );
      emit(
        state.copyWith(
          status: VerifyProofOfFundsStatus.success,
          result: result,
        ),
      );
    } on CoinsError catch (e) {
      emit(state.copyWith(status: VerifyProofOfFundsStatus.error, error: e));
    } catch (e) {
      emit(
        state.copyWith(
          status: VerifyProofOfFundsStatus.error,
          error: CoinsError.unexpected(message: e.toString()),
        ),
      );
    }
  }

  void clearError() => emit(state.copyWith(error: null));
}
