import 'package:bb_mobile/_pkg/mnemonic_word.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'words_cubit.freezed.dart';

@freezed
class WordsState with _$WordsState {
  const factory WordsState({
    List<String>? words,
    @Default('') String err,
    @Default(false) bool loading,
  }) = _WordsState;
  const WordsState._();

  List<String> findWords(String str) {
    if (str.isEmpty) return [];

    return words!
        .where(
          (word) => word.toLowerCase().contains(
                str.toLowerCase(),
              ),
        )
        .toList();
  }
}

class WordsCubit extends Cubit<WordsState> {
  WordsCubit({
    required this.mnemonicWords,
  }) : super(const WordsState()) {
    loadWords();
  }

  final MnemonicWords mnemonicWords;

  Future<void> loadWords() async {
    emit(state.copyWith(loading: true));
    final (words, err) = await mnemonicWords.loadWordList();
    if (err != null) {
      emit(state.copyWith(err: err.toString(), loading: false));
      return;
    }
    emit(state.copyWith(words: words, loading: false));
  }
}
