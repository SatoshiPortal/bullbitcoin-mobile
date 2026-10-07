import 'package:bull_recoverbull/src/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/data/recoverbull_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../support/log_sink.dart';

class _MockRemote extends Mock implements RecoverBullRemoteDatasource {}

class _MockSettings extends Mock implements RecoverbullSettingsDatasource {}

void main() {
  const oldFixture =
      '{"created_at":784044000000,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608\'/0\'/586053381"}';
  const oldKey =
      '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';
  const newFixture =
      '{"created_at":1759844619801,"id":"4958a5130b77d4359b88a541998351f04e595060e867e8ea5cd2e8efdc4cddaa","ciphertext":"wBeihGFKLoCQeSZhhX7Nh7zbMzt5If/5QayQ4MuzsQ1X8DgUFo+FbdpPx3KB8Xjwe25DknAc5TIU9zbIDoETIGCWZohvVt1sL5L+bweLVijbJlUQub0va3ZlYSR5QeHVfisaKlS2Psv5mqF9XK6vyq7fiM5qHnDeKG5edDblm8qEh/K/2Ogn9v1ZEKf2BJQFzpJxy7/sCAciZ0j+hY6SNkWVZIyQiLn9+mVGIEjKdPDadP8lvt8CYE4Y5vGfIKo2Mw5ziCdYHCZ+eiG6m+GK9yqdX4n3je1VffYFSIze5vNbgcdgM/uL9BJgiz3iC4d29ble1Uac8MleObrnScB7MCHuMVevwLdFm8kt+TGMbZ2t/MH/xxsUtTFJH7cjuz3ykZtIzfR+CPTkB3OZ637SunzYUcQ70mFzkk/e8xdLjZeKP1r27j6LQK/D84x2RVqB","salt":"08ddfdcc4abbc7e159e2bbd6773b80c3","path":"1608\'/0\'/632486385\'"}';
  const newKey =
      '32255e6651db67fa5b5a44240b6a5d2189cb58666bcc3830c35aff5a2b01b84f';
  final expectedMnemonic = [...List.filled(11, 'zoo'), 'wrong'];

  late RecoverBullRepositoryImpl repository;

  setUp(() {
    repository = RecoverBullRepositoryImpl(
      log: TestLogSink.recording(),
      remoteDatasource: _MockRemote(),
      recoverbullSettingsDatasource: _MockSettings(),
    );
  });

  group('restoreVault with published fixtures', () {
    final cases = {
      'old derivation path': (oldFixture, oldKey),
      'new derivation path': (newFixture, newKey),
    };
    for (final entry in cases.entries) {
      test('restores the mnemonic of the ${entry.key} vault', () {
        final result = repository.restoreVault(
          vault: EncryptedVault(file: entry.value.$1),
          vaultKey: entry.value.$2,
        );

        expect(result, isA<Ok<DecryptedVault, RecoverBullFailure>>());
        expect(
          (result as Ok<DecryptedVault, RecoverBullFailure>).value.mnemonic,
          expectedMnemonic,
        );
      });
    }

    test('exposes the derivation path of each fixture', () {
      expect(
        EncryptedVault(file: oldFixture).derivationPath,
        "m/1608'/0'/586053381",
      );
      expect(
        EncryptedVault(file: newFixture).derivationPath,
        "1608'/0'/632486385'",
      );
    });

    test('rejects a vault restored with the other fixture key', () {
      final result = repository.restoreVault(
        vault: EncryptedVault(file: oldFixture),
        vaultKey: newKey,
      );

      expect(result, isA<Err<DecryptedVault, RecoverBullFailure>>());
    });
  });
}
