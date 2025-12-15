import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class MnemonicGenerator {
  const MnemonicGenerator();

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

class FailedToGenerateMnemonicException extends BullException {
  FailedToGenerateMnemonicException(super.message);
}
