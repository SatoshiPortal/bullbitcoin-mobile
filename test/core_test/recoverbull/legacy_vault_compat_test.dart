import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/recoverbull_repository_impl.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

class _MockRemote extends Mock implements RecoverBullRemoteDatasource {}

class _MockSettings extends Mock implements RecoverbullSettingsDatasource {}

/// Vault files written by earlier app versions (no `version` field), taken
/// from integration_test/recoverbull_test.dart. The client's strict backup
/// validation must keep accepting them, or users could not restore.
const _oldPathVault =
    """{"created_at":784044000000,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608'/0'/586053381"}""";
const _oldPathVaultKey =
    '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';

const _newPathVault =
    """{"created_at":1759844619801,"id":"4958a5130b77d4359b88a541998351f04e595060e867e8ea5cd2e8efdc4cddaa","ciphertext":"wBeihGFKLoCQeSZhhX7Nh7zbMzt5If/5QayQ4MuzsQ1X8DgUFo+FbdpPx3KB8Xjwe25DknAc5TIU9zbIDoETIGCWZohvVt1sL5L+bweLVijbJlUQub0va3ZlYSR5QeHVfisaKlS2Psv5mqF9XK6vyq7fiM5qHnDeKG5edDblm8qEh/K/2Ogn9v1ZEKf2BJQFzpJxy7/sCAciZ0j+hY6SNkWVZIyQiLn9+mVGIEjKdPDadP8lvt8CYE4Y5vGfIKo2Mw5ziCdYHCZ+eiG6m+GK9yqdX4n3je1VffYFSIze5vNbgcdgM/uL9BJgiz3iC4d29ble1Uac8MleObrnScB7MCHuMVevwLdFm8kt+TGMbZ2t/MH/xxsUtTFJH7cjuz3ykZtIzfR+CPTkB3OZ637SunzYUcQ70mFzkk/e8xdLjZeKP1r27j6LQK/D84x2RVqB","salt":"08ddfdcc4abbc7e159e2bbd6773b80c3","path":"1608'/0'/632486385'"}""";
const _newPathVaultKey =
    '32255e6651db67fa5b5a44240b6a5d2189cb58666bcc3830c35aff5a2b01b84f';

final _expectedMnemonic = [...List.filled(11, 'zoo'), 'wrong'];

void main() {
  late RecoverBullRepositoryImpl repository;

  setUp(() {
    repository = RecoverBullRepositoryImpl(
      remoteDatasource: _MockRemote(),
      recoverbullSettingsDatasource: _MockSettings(),
    );
  });

  group('vaults written by earlier app versions', () {
    for (final (name, file, key) in [
      ('old derivation path', _oldPathVault, _oldPathVaultKey),
      ('new derivation path', _newPathVault, _newPathVaultKey),
    ]) {
      test('$name: passes strict validation and decrypts', () {
        expect(EncryptedVault.isValid(file), isTrue);

        final vault = EncryptedVault(file: file);
        final result = repository.restoreVault(vault: vault, vaultKey: key);

        expect(result, isA<Ok<DecryptedVault, RecoverBullCoreFailure>>());
        final decrypted =
            (result as Ok<DecryptedVault, RecoverBullCoreFailure>).value;
        expect(decrypted.mnemonic, _expectedMnemonic);
      });
    }
  });

  test('a vault written now round-trips through strict validation', () {
    const key =
        '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
    final created = repository.createVault(
      vaultKey: key,
      plaintext: json.encode(DecryptedVault(mnemonic: _expectedMnemonic)),
      derivationPath: "1608'/0'/1'",
    );
    final vault = (created as Ok<EncryptedVault, RecoverBullCoreFailure>).value;

    // New files declare the format version; the previous client ignores
    // unknown keys, so older app versions can still read them.
    expect((json.decode(vault.toFile()) as Map<String, dynamic>)['version'], 1);

    final reparsed = EncryptedVault(file: vault.toFile());
    final result = repository.restoreVault(vault: reparsed, vaultKey: key);

    expect(reparsed.derivationPath, "1608'/0'/1'");
    expect(
      (result as Ok<DecryptedVault, RecoverBullCoreFailure>).value.mnemonic,
      _expectedMnemonic,
    );
  });

  test('the default key server URL is accepted by the client', () {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    expect(
      () => recoverbull.KeyServer(
        address: Uri.parse(SettingsConstants.recoverbullUrl),
        client: client,
      ),
      returnsNormally,
    );
  });
}
