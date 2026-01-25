import 'package:bb_mobile/features/secrets/domain/mnemonic_words.dart';

abstract interface class MnemonicGeneratorPort {
  // Currently our business rule is to generate a 12-word mnemonic in English,
  // so no parameters for now.
  Future<MnemonicWords> generateMnemonic();
}
