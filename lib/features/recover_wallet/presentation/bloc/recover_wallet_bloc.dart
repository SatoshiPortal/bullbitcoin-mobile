import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/features/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recover_wallet_event.dart';
part 'recover_wallet_state.dart';
part 'recover_wallet_bloc.freezed.dart';

class RecoverWalletBloc extends Bloc<RecoverWalletEvent, RecoverWalletState> {
  RecoverWalletBloc({
    required FindMnemonicWordsUseCase findMnemonicWordsUseCase,
    required RecoverWalletUseCase recoverWalletUseCase,
  })  : _findMnemonicWordsUseCase = findMnemonicWordsUseCase,
        _recoverWalletUseCase = recoverWalletUseCase,
        super(const RecoverWalletState()) {
    on<RecoverWalletWordsCountChanged>(_onWordsCountChanged);
    on<RecoverWalletWordChanged>(_onWordChanged);
    on<RecoverWalletPassphraseChanged>(_onPassphraseChanged);
    on<RecoverWalletLabelChanged>(_onLabelChanged);
    on<RecoverWalletConfirmed>(_onConfirmed);
  }

  final FindMnemonicWordsUseCase _findMnemonicWordsUseCase;
  final RecoverWalletUseCase _recoverWalletUseCase;

  void _onWordsCountChanged(
    RecoverWalletWordsCountChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    final words = Map<int, String>.from(state.validWords);
    final hintWords = Map<int, List<String>>.from(state.hintWords);
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

    if (hintWords[wordIndex]?.contains(word) == true) {
      // A valid mnemonic word was entered,so add it to validWords
      validWords[event.index] = event.word;
    } else {
      // Word is not in the list of valid words, so remove any previous
      //  valid word at the same index
      validWords.remove(event.index);
    }

    emit(
      state.copyWith(
        validWords: validWords,
        hintWords: hintWords,
      ),
    );
  }

  void _onPassphraseChanged(
    RecoverWalletPassphraseChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    emit(state.copyWith(passphrase: event.passphrase));
  }

  void _onLabelChanged(
    RecoverWalletLabelChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    emit(state.copyWith(label: event.label));
  }

  Future<void> _onConfirmed(
    RecoverWalletConfirmed event,
    Emitter<RecoverWalletState> emit,
  ) async {
    try {
      await _recoverWalletUseCase.execute(
        mnemonicWords: state.validWords.values.toList(),
        passphrase: state.passphrase,
        scriptType: state.scriptType,
        label: state.label,
      );
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
