import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/bip85_bip39_language.dart';
import 'package:bb_mobile/core/seed/domain/entity/bip85_bip39_word_count.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

abstract class SeedRepository {
  Future<MnemonicSeed> createFromMnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  });
  Future<MnemonicSeed> createBip85DerivedFromMasterSeed({
    required String masterSeedFingerprint,
    required Bip85Bip39Language language,
    required Bip85Bip39WordCount wordCount,
    required int accountIndex,
    String? passphrase,
  });
  Future<Seed> createFromBytes({required Uint8List bytes});
  Future<Seed> get(String fingerprint);
  Future<bool> exists(String fingerprint);
  Future<void> delete(String fingerprint);
}
