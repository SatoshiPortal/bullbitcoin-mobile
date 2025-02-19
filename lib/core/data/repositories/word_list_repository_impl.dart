import 'package:bb_mobile/core/data/datasources/bip39_word_list_data_source.dart';
import 'package:bb_mobile/core/domain/repositories/word_list_repository.dart';

class WordListRepositoryImpl implements WordListRepository {
  final Bip39WordListDataSource _dataSource;
  late List<String> _words = [];

  WordListRepositoryImpl({required Bip39WordListDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<List<String>> getWordsStartingWith(String firstLetters) async {
    _words = _words.isEmpty ? await _dataSource.getWords() : _words;

    return _words.where((word) => word.startsWith(firstLetters)).toList();
  }
}
