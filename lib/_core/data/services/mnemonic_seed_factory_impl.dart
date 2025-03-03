import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class MnemonicSeedFactoryImpl implements MnemonicSeedFactory {
  const MnemonicSeedFactoryImpl();

  @override
  Future<MnemonicSeed> generate({String? passphrase}) async {
    try {
      final mnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);

      final mnemonicWords = mnemonic.asString().split(' ');
      return MnemonicSeed(
        mnemonicWords: mnemonicWords,
      );
    } catch (e) {
      throw FailedToGenerateMnemonicSeedException(e.toString());
    }
  }

  @override
  MnemonicSeed fromWords(
    List<String> mnemonicWords, {
    String? passphrase,
  }) {
    return MnemonicSeed(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    );
  }
}

class FailedToGenerateMnemonicSeedException implements Exception {
  final String message;

  FailedToGenerateMnemonicSeedException(this.message);
}
