abstract class WordListRepository {
  Future<List<String>> getWordsStartingWith(String firstLetters);
}
