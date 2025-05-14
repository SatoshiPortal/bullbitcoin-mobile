import 'package:bb_mobile/core/seed/domain/services/mnemonic_generator.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class MnemonicGeneratorImpl implements MnemonicGenerator {
  const MnemonicGeneratorImpl();

  @override
  Future<List<String>> generate() async {
    try {
      final mnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);

      final mnemonicWords = mnemonic.asString().split(' ');
      return mnemonicWords;
    } catch (e) {
      throw FailedToGenerateMnemonicException(e.toString());
    }
  }
}

class FailedToGenerateMnemonicException implements Exception {
  final String message;

  FailedToGenerateMnemonicException(this.message);
}
