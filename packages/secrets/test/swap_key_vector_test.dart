import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/crypto/derivers/derivers.dart' show Deriver;
import 'package:secrets/src/data/secret_repository.dart' show SecretRepository;

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

/// What `swapKey` hands out is a BIP85 child of the wallet, never the wallet's own words.
///
/// `Secret.swapKey` is one of the package's material exits, and the only one whose value is computed outside Dart: boltz-client 0.4.1 (`util/secrets.rs`, `SwapMasterKey::new`) derives the swap mnemonic as the 12-word BIP85 child at index 26589 of the wallet root, then builds the swap master key from that child alone. boltz has no host library, so `swapKey` itself runs only on a device (`integration_test/secrets_derivation_vectors_test.dart`); this pins the half that is pure Dart — that the child boltz publishes for a fixed wallet is the one this package's own BIP85 derives — against boltz's own test vector, so the device test compares against an oracle that is not boltz.
void main() {
  test(
    "boltz's published swap mnemonic is the BIP85 child 26589 of the wallet",
    () async {
      // boltz-dart 2a94c9b0, rust/src/api/secrets.rs, test `derives_index0_preimage_and_key_via_wrapper`.
      const wallet = <String>[
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
        'bacon',
      ];
      const boltzSwapMnemonic =
          'velvet engage shaft effort clarify annual protect client only surround sock gain';

      FakeSecureStoragePlatform().install();
      final repo = SecretRepository();
      final info = ok(await repo.store(words: wallet));
      final material = ok(await repo.use(info, (m) => m));

      final child = Deriver.bip85.mnemonic(
        material,
        language: bip39.Language.english,
        length: bip39.MnemonicLength.words12,
        index: 26589,
      );

      expect(child.join(' '), boltzSwapMnemonic);
      expect(child, isNot(wallet));
    },
  );
}
