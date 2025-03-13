import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recover_wallet_bloc.freezed.dart';
part 'recover_wallet_event.dart';
part 'recover_wallet_state.dart';

class RecoverWalletBloc extends Bloc<RecoverWalletEvent, RecoverWalletState> {
  RecoverWalletBloc({
    required FindMnemonicWordsUseCase findMnemonicWordsUseCase,
    required RecoverWalletUseCase recoverWalletUseCase,
    bool useTestWallet = false,
  })  : _findMnemonicWordsUseCase = findMnemonicWordsUseCase,
        _recoverWalletUseCase = recoverWalletUseCase,
        super(const RecoverWalletState()) {
    on<RecoverWalletWordsCountChanged>(_onWordsCountChanged);
    on<RecoverWalletWordChanged>(_onWordChanged);
    on<RecoverWalletPassphraseChanged>(_onPassphraseChanged);
    on<RecoverWalletLabelChanged>(_onLabelChanged);
    on<RecoverWalletConfirmed>(_onConfirmed);
    on<RecoverFromOnboarding>(_onRecoverFromOnboarding);
    on<ImportTestableWallet>(_importTestableWallet);
    on<ClearUntappedWords>(_clearUntappedWords);

    if (!kReleaseMode) {
      add(ImportTestableWallet(useTestWallet: useTestWallet));
    }
  }

  final FindMnemonicWordsUseCase _findMnemonicWordsUseCase;
  final RecoverWalletUseCase _recoverWalletUseCase;

  void _importTestableWallet(
    ImportTestableWallet event,
    Emitter<RecoverWalletState> emit,
  ) {
    if (event.useTestWallet) {
      final words = importWords(secureTN1);
      for (int i = 0; i < words.length; i++) {
        final word = words[i] ?? '';
        add(RecoverWalletWordChanged(index: i, word: word, tapped: true));
      }

      return;
    }
  }

  void _onRecoverFromOnboarding(
    RecoverFromOnboarding event,
    Emitter<RecoverWalletState> emit,
  ) {
    emit(state.copyWith(fromOnboarding: true));
  }

  void _onWordsCountChanged(
    RecoverWalletWordsCountChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    final words = Map<int, String>.from(state.validWords);
    final hintWords = Map<int, List<String>>.from(state.hintWords);

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

    hintWords[wordIndex] = await _findMnemonicWordsUseCase.execute(word);

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

  Future<void> _clearUntappedWords(
    ClearUntappedWords event,
    Emitter<RecoverWalletState> emit,
  ) async {}

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
      emit(state.copyWith(isCreating: true));
      await _recoverWalletUseCase.execute(
        mnemonicWords: state.validWords.values.toList(),
        passphrase: state.passphrase,
        scriptType: state.scriptType,
        label: state.label,
        isDefault: state.fromOnboarding,
      );

      emit(
        state.copyWith(
          status: RecoverWalletStatus.success,
          isCreating: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: e,
          isCreating: false,
        ),
      );
    }
  }
}
