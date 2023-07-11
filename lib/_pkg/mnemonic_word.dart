import 'package:bb_mobile/_pkg/error.dart';
import 'package:flutter/services.dart' show rootBundle;

class MnemonicWords {
  Future<(List<String>?, Err?)> loadWordList() async {
    try {
      final i = await rootBundle.loadString('assets/bip39_english.txt');
      final words = i.split('\n');
      return (words, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
