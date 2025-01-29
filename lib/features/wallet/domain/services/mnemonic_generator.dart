import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

abstract class MnemonicGenerator {
  Future<List<String>> generateMnemonic();
}

class BdkMnemonicGeneratorImpl implements MnemonicGenerator {
  const BdkMnemonicGeneratorImpl();

  @override
  Future<List<String>> generateMnemonic() async {
    try {
      final mnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);
      final words = mnemonic.asString().split(' ');
      return words;
    } catch (e) {
      throw FailedToGenerateMnemonicException(e.toString());
    }
  }
}

class FailedToGenerateMnemonicException implements Exception {
  final String message;

  FailedToGenerateMnemonicException(this.message);
}
