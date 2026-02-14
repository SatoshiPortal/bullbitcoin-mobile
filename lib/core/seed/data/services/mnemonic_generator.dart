import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bdk_dart/bdk.dart' as bdk;

class MnemonicGenerator {
  const MnemonicGenerator();

  List<String> generate() {
    try {
      final mnemonic = bdk.Mnemonic(bdk.WordCount.words12);

      final mnemonicWords = mnemonic.toString().split(' ');
      return mnemonicWords;
    } catch (e) {
      throw FailedToGenerateMnemonicException(e.toString());
    }
  }
}

class FailedToGenerateMnemonicException extends BullException {
  FailedToGenerateMnemonicException(super.message);
}
