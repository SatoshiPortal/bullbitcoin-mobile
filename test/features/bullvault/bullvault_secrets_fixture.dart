import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

final class BullVaultSecretsFixture {
  final storage = FakeSecureStoragePlatform();
  final secrets = Secrets(scratchDirectory: () async => '/tmp');

  BullVaultSecretsFixture() {
    storage.install();
  }

  Future<Secret> mnemonic(List<String> words, {String passphrase = ''}) async {
    final account = await secrets.preview.account(
      words: words,
      derivationPath: "m/48'/1'/0'/2'",
      network: BitcoinNetwork.testnet,
      passphrase: passphrase,
    );
    final id =
        (account as Ok<PublicAccountKey, SecretFailure>).value.fingerprint;
    if (await secrets.fetch(id) case Ok(:final value)) return value;
    return (await secrets.import(words: words, passphrase: passphrase)
            as Ok<Secret, SecretFailure>)
        .value;
  }

  Future<Secret> rawSeed() async {
    final bytes = Uint8List.fromList(List<int>.generate(64, (index) => index));
    final id = Fingerprint(bip32.Bip32Keys.fromSeed(bytes).fingerprintHex);
    storage.entries['seed_${id.hex}'] = jsonEncode({
      'runtimeType': 'bytes',
      'bytes': bytes,
    });
    return (await secrets.fetch(id) as Ok<Secret, SecretFailure>).value;
  }
}
