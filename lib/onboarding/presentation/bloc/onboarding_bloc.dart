import 'package:bb_mobile/_core/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
    required FindMnemonicWordsUsecase findMnemonicWordsUsecase,
  })  : _createDefaultWalletsUsecase = createDefaultWalletsUsecase,
        _findMnemonicWordsUsecase = findMnemonicWordsUsecase,
        super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoveryWordChanged>(_onRecoveryWordChanged);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);
    on<OnboardingGoToRecoverStep>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.recoveryWords));
    });
    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });
  }

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;
  final FindMnemonicWordsUsecase _findMnemonicWordsUsecase;

  Future<void> _onCreateNewWallet(
    OnboardingCreateNewWallet event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(state.copyWith(creating: true, error: null));
      await _createDefaultWalletsUsecase.execute();
      emit(state.copyWith(creating: false, step: OnboardingStep.createSucess));
    } catch (e) {
      emit(state.copyWith(error: e, creating: false));
    }
  }

  Future<void> _onRecoveryWordChanged(
    OnboardingRecoveryWordChanged event,
    Emitter<OnboardingState> emit,
  ) async {
    final wordIndex = event.index;
    final word = event.word;
    final validWords = Map<int, String>.from(state.validWords);
    final hintWords = Map<int, List<String>>.from(state.hintWords);

    hintWords[wordIndex] = await _findMnemonicWordsUsecase.execute(word);

    if (hintWords[wordIndex]?.contains(word) == true) {
      validWords[event.index] = event.word;
    } else {
      validWords.remove(event.index);
    }

    emit(
      state.copyWith(
        validWords: validWords,
        hintWords: hintWords,
      ),
    );
  }

  Future<void> _onRecoverWalletClicked(
    OnboardingRecoverWalletClicked event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(state.copyWith(creating: true, error: null, hintWords: {}));
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: state.validWords.values.toList(),
      );

      emit(
        state.copyWith(
          step: OnboardingStep.recoverySuccess,
          creating: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: e,
          creating: false,
        ),
      );
    }
  }
}
