import 'package:bb_mobile/features/seeds/application/ports/mnemonic_generator_port.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BdkMnemonicGeneratorPort implements MnemonicGeneratorPort {
  const BdkMnemonicGeneratorPort();

  @override
  Future<List<String>> generateMnemonic() async {
    final mnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);

    final mnemonicWords = mnemonic.asString().split(' ');
    return mnemonicWords;
  }
}
