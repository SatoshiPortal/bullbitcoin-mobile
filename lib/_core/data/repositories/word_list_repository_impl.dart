import 'package:bb_mobile/_core/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/_utils/bip39.dart';

class WordListRepositoryImpl implements WordListRepository {
  late List<String> _words = [];

  WordListRepositoryImpl();

  @override
  Future<List<String>> getWordsStartingWith(String firstLetters) async {
    _words = _words.isEmpty ? await Bip39WordList.all() : _words;
    return _words.where((word) => word.startsWith(firstLetters)).toList();
  }
}
