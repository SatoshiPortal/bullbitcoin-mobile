import 'package:bb_mobile/_core/domain/entities/seed.dart';

abstract class MnemonicSeedFactory {
  Future<MnemonicSeed> generate({String? passphrase});
  MnemonicSeed fromWords(
    List<String> mnemonicWords, {
    String? passphrase,
  });
}
