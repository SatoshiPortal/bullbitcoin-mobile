import 'package:bb_mobile/features/psbt_signing/domain/usecases/review_psbt_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/domain/usecases/sign_external_psbt_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PsbtSigningCubit extends Cubit<PsbtSigningState> {
  final String walletId;
  final ReviewPsbtUsecase _reviewPsbtUsecase;
  final SignExternalPsbtUsecase _signExternalPsbtUsecase;
  var _reviewGeneration = 0;

  PsbtSigningCubit({
    required this.walletId,
    required this._reviewPsbtUsecase,
    required this._signExternalPsbtUsecase,
  }) : super(const PsbtSigningState());

  Future<void> review(String psbt) async {
    final generation = ++_reviewGeneration;
    if (psbt.trim().isEmpty) {
      emit(const PsbtSigningState());
      return;
    }
    emit(
      state.copyWith(
        input: psbt,
        isReviewing: true,
        clearReview: true,
        clearResult: true,
        clearFailure: true,
      ),
    );
    final result = await _reviewPsbtUsecase.execute(
      walletId: walletId,
      psbt: psbt,
    );
    if (isClosed || generation != _reviewGeneration) return;
    result.fold(
      (review) => emit(
        state.copyWith(
          step: PsbtSigningStep.review,
          review: review,
          isReviewing: false,
          clearFailure: true,
        ),
      ),
      (failure) => emit(
        state.copyWith(
          step: PsbtSigningStep.input,
          failure: failure,
          isReviewing: false,
        ),
      ),
    );
  }

  Future<void> sign({String? passphrase}) async {
    final review = state.review;
    if (review == null || state.isSigning) return;
    emit(state.copyWith(isSigning: true, clearFailure: true));
    final result = await _signExternalPsbtUsecase.execute(
      review,
      passphrase: passphrase,
    );
    if (isClosed) return;
    result.fold(
      (signed) => emit(
        state.copyWith(
          step: PsbtSigningStep.signed,
          result: signed,
          isSigning: false,
          clearFailure: true,
        ),
      ),
      (failure) => emit(state.copyWith(isSigning: false, failure: failure)),
    );
  }

  void edit() => emit(
    state.copyWith(
      step: PsbtSigningStep.input,
      clearReview: true,
      clearResult: true,
      clearFailure: true,
    ),
  );
}
