import 'package:bb_mobile/core_deprecated/utils/bip39.dart';

class WordListRepository {
  WordListRepository();

  List<String> getWordsStartingWith(String firstLetters) {
    final words = Bip39WordList.english();
    return words.where((word) => word.startsWith(firstLetters)).toList();
  }
}
