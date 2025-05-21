import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

abstract class SeedRepository {
  Future<MnemonicSeed> createFromMnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  });
  Future<Seed> createFromBytes({required Uint8List bytes});
  Future<Seed> get(String fingerprint);
  Future<bool> exists(String fingerprint);
  Future<void> delete(String fingerprint);
}
