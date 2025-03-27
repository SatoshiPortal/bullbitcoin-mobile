import 'package:bb_mobile/core/domain/repositories/word_list_repository.dart';

class FindMnemonicWordsUsecase {
  final WordListRepository _wordListRepository;

  FindMnemonicWordsUsecase({
    required WordListRepository wordListRepository,
  }) : _wordListRepository = wordListRepository;

  Future<List<String>> execute(String firstLetters) async {
    final words = await _wordListRepository.getWordsStartingWith(firstLetters);

    return words;
  }
}
