import 'package:bb_mobile/_core/domain/repositories/word_list_repository.dart';

class FindMnemonicWordsUseCase {
  final WordListRepository _wordListRepository;

  FindMnemonicWordsUseCase({
    required WordListRepository wordListRepository,
  }) : _wordListRepository = wordListRepository;

  Future<List<String>> execute(String firstLetters) async {
    final words = await _wordListRepository.getWordsStartingWith(firstLetters);

    return words;
  }
}
