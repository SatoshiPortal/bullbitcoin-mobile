import 'package:bb_mobile/features/wallet/domain/entities/seed.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

abstract class SeedGenerator {
  Future<MnemonicSeed> newMnemonicSeed({String? passphrase});
}

class BdkSeedGeneratorImpl implements SeedGenerator {
  const BdkSeedGeneratorImpl();

  @override
  Future<MnemonicSeed> newMnemonicSeed({
    String? passphrase,
  }) async {
    try {
      final mnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);

      return MnemonicSeed(
        mnemonicWords: mnemonic.asString().split(' '),
        passphrase: passphrase,
      );
    } catch (e) {
      throw FailedToGenerateNewSeedException(e.toString());
    }
  }
}

class FailedToGenerateNewSeedException implements Exception {
  final String message;

  FailedToGenerateNewSeedException(this.message);
}
