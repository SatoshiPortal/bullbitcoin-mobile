import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

abstract class MnemonicGenerator {
  Future<List<String>> get newMnemonic;
}

class BdkMnemonicGeneratorImpl implements MnemonicGenerator {
  const BdkMnemonicGeneratorImpl();

  @override
  Future<List<String>> get newMnemonic async {
    try {
      final mnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);

      return mnemonic.asString().split(' ');
    } catch (e) {
      throw FailedToGenerateNewMnemonicException(e.toString());
    }
  }
}

class FailedToGenerateNewMnemonicException implements Exception {
  final String message;

  FailedToGenerateNewMnemonicException(this.message);
}
