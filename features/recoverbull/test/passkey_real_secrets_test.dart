import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/passkey_password_deriver.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

T ok<T>(Result<T, dynamic> value) => (value as Ok<T, dynamic>).value;

void main() {
  test(
    'a real Regtest vault opens after a fresh custody installation',
    () async {
      FakeSecureStoragePlatform().install();
      final initial = custody.Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => '.',
      );
      final words = '${'zoo ' * 11}wrong'.split(' ');
      final secret = ok(
        await initial.import(words: words, language: custody.Language.english),
      );
      final vaults = SecretsVaultRepository(initial);
      final backup = ok(
        await vaults.create(
          VaultContext(fingerprint: secret.id, network: BitcoinNetwork.regtest),
        ),
      );
      final public = VaultPasskey(
        rpId: 'passkey.example.com',
        credentialId: [1, 2, 3],
        prfSalt: List.generate(32, (i) => i),
      );
      final original = backup.vault;
      final secured = EncryptedVault(
        id: original.id,
        salt: original.salt,
        ciphertext: original.ciphertext,
        createdAt: original.createdAt,
        derivationPath: original.derivationPath,
        passkey: public,
      );
      final prf = Uint8List.fromList(List.filled(32, 7));
      const deriver = PasskeyPasswordDeriver();
      final password = deriver.derive(prf, secured);
      final file = vaults.encode(secured);
      expect(file, isNot(contains(words.join(' '))));
      expect(file, isNot(contains(backup.key.hex)));
      expect(file, isNot(contains(password)));
      expect(file, isNot(contains(base64Url.encode(prf).replaceAll('=', ''))));
      prf.fillRange(0, prf.length, 0);

      FakeSecureStoragePlatform().install();
      final fresh = custody.Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => '.',
      );
      final recoveredVaults = SecretsVaultRepository(fresh);
      final selected = ok(recoveredVaults.parse(file));
      final retrieved = Uint8List.fromList(List.filled(32, 7));
      expect(deriver.derive(retrieved, selected), password);
      retrieved.fillRange(0, retrieved.length, 0);
      final restored = ok(await recoveredVaults.restore(selected, backup.key));
      expect(restored, secret.id);
      expect(ok(await fresh.exists(secret.id)), isTrue);
    },
  );
}
