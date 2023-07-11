import 'package:bb_mobile/_pkg/mnemonic_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Load words from assets', (_) async {
    final (words, _) = await MnemonicWords().loadWordList();
    expect(words!.length, 2048);
  });
}
