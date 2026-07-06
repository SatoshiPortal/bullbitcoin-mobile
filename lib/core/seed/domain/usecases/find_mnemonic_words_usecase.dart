import 'package:bb_mobile/core/seed/data/repository/word_list_repository.dart';

class FindMnemonicWordsUsecase {
  final WordListRepository _wordListRepository;

  FindMnemonicWordsUsecase({required this._wordListRepository});

  List<String> execute(String firstLetters) {
    final words = _wordListRepository.getWordsStartingWith(firstLetters);
    return words;
  }
}
