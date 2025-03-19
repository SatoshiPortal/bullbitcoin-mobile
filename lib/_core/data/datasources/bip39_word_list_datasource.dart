import 'package:flutter/services.dart';

abstract class Bip39WordListDatasource {
  Future<List<String>> getWords();
}

class Bip39EnglishWordListDatasourceImpl implements Bip39WordListDatasource {
  @override
  Future<List<String>> getWords() async {
    final i = await rootBundle.loadString('assets/bip39_english.txt');
    return i.split('\n');
  }
}
