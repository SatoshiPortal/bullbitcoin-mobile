import 'package:flutter/services.dart';

abstract class Bip39WordListDataSource {
  Future<List<String>> getWords();
}

class Bip39EnglishWordListDataSource implements Bip39WordListDataSource {
  @override
  Future<List<String>> getWords() async {
    final i = await rootBundle.loadString('assets/bip39_english.txt');
    return i.split('\n');
  }
}
