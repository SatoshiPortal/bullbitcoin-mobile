import 'dart:async';

import 'package:bb_mobile/core/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recover_wallet_bloc.freezed.dart';
part 'recover_wallet_event.dart';
part 'recover_wallet_state.dart';

class RecoverWalletBloc extends Bloc<RecoverWalletEvent, RecoverWalletState> {
  RecoverWalletBloc({
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
    required FindMnemonicWordsUsecase findMnemonicWordsUsecase,
    bool useTestWallet = false,
  })  : _findMnemonicWordsUsecase = findMnemonicWordsUsecase,
        _createDefaultWalletsUsecase = createDefaultWalletsUsecase,
        super(const RecoverWalletState()) {
    on<RecoverWalletWordsCountChanged>(_onWordsCountChanged);
    on<RecoverWalletWordChanged>(_onWordChanged);
    on<RecoverWalletPassphraseChanged>(_onPassphraseChanged);
    on<RecoverWalletLabelChanged>(_onLabelChanged);
    on<RecoverWalletConfirmed>(_onConfirmed);
    on<ImportTestableWallet>(_importTestableWallet);
    on<ClearUntappedWords>(_clearUntappedWords);

    if (!kReleaseMode) {
      add(ImportTestableWallet(useTestWallet: useTestWallet));
    }
  }

  final FindMnemonicWordsUsecase _findMnemonicWordsUsecase;
  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;

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
    try {
      final wordIndex = event.index;
      final word = event.word.trim().toLowerCase();
      final validWords = Map<int, String>.from(state.validWords);
      final hintWords = Map<int, List<String>>.from(state.hintWords);

      hintWords[wordIndex] = await _findMnemonicWordsUsecase.execute(word);

      if (hintWords[wordIndex]?.contains(word) == true) {
        validWords[wordIndex] = word;
      } else {
        validWords.remove(wordIndex);
      }

      emit(
        state.copyWith(
          validWords: validWords,
          hintWords: hintWords,
          recoverWalletStatus: const RecoverWalletStatus.initial(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          recoverWalletStatus:
              RecoverWalletStatus.failure('Failed to validate word: $e'),
        ),
      );
    }
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
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.loading(),
        ),
      );
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: state.validWords.values.toList(),
        passphrase: state.passphrase,
      );

      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.success(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          recoverWalletStatus: RecoverWalletStatus.failure(e.toString()),
        ),
      );
    }
  }
}
