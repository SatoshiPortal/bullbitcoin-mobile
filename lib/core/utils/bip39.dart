import 'package:flutter/services.dart';

class Bip39WordList {
  static Future<List<String>> all() async {
    final i = await rootBundle.loadString('assets/bip39_english.txt');
    return i.split('\n');
  }
}
