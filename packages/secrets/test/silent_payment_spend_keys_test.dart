import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/derivers.dart' show Deriver;
import 'package:secrets/src/data/secret_repository.dart' show SecretRepository;
import 'package:secrets/src/domain/secret_material.dart' show SecretMaterial;

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

/// The spend authority `SilentPaymentSigner` lends bwk's signer for one call.
///
/// bwk's signer refuses an input neither key can be proven to own, and the
/// account's finalize refuses a PSBT that pays other keys, so a mismatch here
/// would fail loudly on a device; these tests pin, without a device, that the
/// two halves of the package agree — the spend key lent is the one whose
/// public key the scan credential published, and the taproot key lent is the
/// account key behind the descriptor — and that what is lent is the BIP86
/// account key, never the master key.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  Future<SecretMaterial> material({String passphrase = ''}) async {
    final repo = SecretRepository();
    final info = ok(await repo.store(words: words, passphrase: passphrase));
    return ok(await repo.use(info, (m) => m));
  }

  setUp(() => FakeSecureStoragePlatform().install());

  for (final network in BitcoinNetwork.values) {
    group(network.name, () {
      final versions = network.isMainnet
          ? (private: 0x0488ade4, public: 0x0488b21e, prefix: 'xprv')
          : (private: 0x04358394, public: 0x043587cf, prefix: 'tprv');
      final type = bip32.NetworkType(
        wif: network.isMainnet ? 0x80 : 0xef,
        bip32: bip32.Bip32Type(
          public: versions.public,
          private: versions.private,
        ),
      );

      test(
        'the spend key lent is the one the scan credential publishes',
        () async {
          final secret = await material();
          final scan = Deriver.bip352.scanKey(secret, network: network);
          final keys = Deriver.bip352.spendKeys(secret, network: network);

          final spend = bip32.Bip32Keys.fromPrivateKey(
            keys.spendPrivateKey,
            Uint8List(32),
          );
          final published = RegExp(
            r',(0[23][0-9a-f]{64})\)$',
          ).firstMatch(scan.sp)!.group(1);
          expect(convert.hex.encode(spend.public), published);
        },
      );

      test('the taproot key lent is the BIP86 account key behind the '
          'descriptor', () async {
        final secret = await material();
        final scan = Deriver.bip352.scanKey(secret, network: network);
        final keys = Deriver.bip352.spendKeys(secret, network: network);

        expect(keys.taprootAccountXprv, startsWith(versions.prefix));
        final account = bip32.Bip32Keys.fromBase58(
          keys.taprootAccountXprv,
          network: type,
        );
        expect(account.depth, 3, reason: 'm/86h/coinh/0h, not the master');
        final xpub = RegExp(
          r'\][xt]pub[1-9A-HJ-NP-Za-km-z]+',
        ).firstMatch(scan.taproot)!.group(0)!.substring(1);
        expect(account.neutered.toBase58(), xpub);
      });

      test('a passphrase changes both keys lent', () async {
        final plain = Deriver.bip352.spendKeys(
          await material(),
          network: network,
        );
        final protected = Deriver.bip352.spendKeys(
          await material(passphrase: 'silent'),
          network: network,
        );
        expect(
          convert.hex.encode(protected.spendPrivateKey),
          isNot(convert.hex.encode(plain.spendPrivateKey)),
        );
        expect(protected.taprootAccountXprv, isNot(plain.taprootAccountXprv));
      });
    });
  }
}
