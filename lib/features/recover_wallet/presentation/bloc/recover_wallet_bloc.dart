import 'package:bb_mobile/features/recover_wallet/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recover_wallet_event.dart';
part 'recover_wallet_state.dart';
part 'recover_wallet_bloc.freezed.dart';

class RecoverWalletBloc extends Bloc<RecoverWalletEvent, RecoverWalletState> {
  RecoverWalletBloc({
    required FindMnemonicWordsUseCase findMnemonicWordsUseCase,
    //required RecoverWalletUseCase recoverWalletUseCase,
  })  : _findMnemonicWordsUseCase = findMnemonicWordsUseCase,
        //_recoverWalletUseCase = recoverWalletUseCase,
        super(const RecoverWalletState()) {
    on<RecoverWalletWordsCountChanged>(_onWordsCountChanged);
    on<RecoverWalletWordChanged>(_onWordChanged);
    on<RecoverWalletConfirmed>(_onConfirmed);
  }

  final FindMnemonicWordsUseCase _findMnemonicWordsUseCase;
  //final RecoverWalletUseCase _recoverWalletUseCase;

  void _onWordsCountChanged(
    RecoverWalletWordsCountChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    final words = state.validWords;
    final hintWords = state.hintWords;
    // Remove words that are not needed anymore if the wordsCount is decreased,
    //  keep the rest so the user should not re-enter them if started with
    //  a wrong wordsCount.
    words.removeWhere((index, _) => index >= event.wordsCount);
    hintWords.removeWhere((index, _) => index >= event.wordsCount);
    emit(
      state.copyWith(
        wordsCount: event.wordsCount,
        validWords: words,
        hintWords: hintWords,
      ),
    );
  }

  Future<void> _onWordChanged(
    RecoverWalletWordChanged event,
    Emitter<RecoverWalletState> emit,
  ) async {
    final wordIndex = event.index;
    final word = event.word;
    final validWords = Map<int, String>.from(state.validWords);
    final hintWords = Map<int, List<String>>.from(state.hintWords);

    // Update the hint words for the entered word
    hintWords[wordIndex] = await _findMnemonicWordsUseCase.execute(word);

    if (hintWords[wordIndex]?.length == 1 &&
        hintWords[wordIndex]?.first == word) {
      // A valid mnemonic word was entered,so add it to validWords
      validWords[event.index] = event.word;
    } else {
      // None or more than one possible words, so not a valid mnemonic word yet.
      // Clear the index of the recovered words.
      validWords.remove(event.index);
    }

    emit(
      state.copyWith(
        validWords: validWords,
        hintWords: hintWords,
      ),
    );
  }

  Future<void> _onConfirmed(
    RecoverWalletConfirmed event,
    Emitter<RecoverWalletState> emit,
  ) async {
    try {
      //await _recoverWalletUseCase.execute(inProgressState.validWords);
      emit(state.copyWith(status: RecoverWalletStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          error: e,
        ),
      );
    }
  }
}
