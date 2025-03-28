import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

abstract class MnemonicSeedFactory {
  Future<MnemonicSeed> generate({String? passphrase});
  MnemonicSeed fromWords(
    List<String> mnemonicWords, {
    String? passphrase,
  });
}
