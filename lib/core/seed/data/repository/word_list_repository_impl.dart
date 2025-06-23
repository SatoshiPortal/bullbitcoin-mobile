import 'package:bb_mobile/core/seed/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/core/utils/bip39.dart';

class WordListRepositoryImpl implements WordListRepository {
  WordListRepositoryImpl();

  @override
  List<String> getWordsStartingWith(String firstLetters) {
    final words = Bip39WordList.english();
    return words.where((word) => word.startsWith(firstLetters)).toList();
  }
}
