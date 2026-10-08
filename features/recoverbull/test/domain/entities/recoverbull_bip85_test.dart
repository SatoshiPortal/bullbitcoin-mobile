import 'dart:typed_data';
import 'dart:convert';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:convert/convert.dart' as convert;
import 'package:bull_recoverbull/src/utils/recoverbull_bip85.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:recoverbull/recoverbull.dart' as sdk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mnemonic = Mnemonic.fromWords(
    words: List.generate(11, (index) => 'zoo') + ['wrong'],
  );
  final xprv = Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed)).toBase58();

  final recoverbullPathWithMissingLastSingleQuote = [
    "m/1608'/0'/586053381",
    "1608'/0'/586053381",
  ];

  const expectedKeyForPath =
      '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';
  const newPath = "1608'/0'/632486385'";
  const newPathKey =
      '32255e6651db67fa5b5a44240b6a5d2189cb58666bcc3830c35aff5a2b01b84f';
  const oldFixture =
      '{"created_at":784044000000,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608\'/0\'/586053381"}';
  const newFixture =
      '{"created_at":1759844619801,"id":"4958a5130b77d4359b88a541998351f04e595060e867e8ea5cd2e8efdc4cddaa","ciphertext":"wBeihGFKLoCQeSZhhX7Nh7zbMzt5If/5QayQ4MuzsQ1X8DgUFo+FbdpPx3KB8Xjwe25DknAc5TIU9zbIDoETIGCWZohvVt1sL5L+bweLVijbJlUQub0va3ZlYSR5QeHVfisaKlS2Psv5mqF9XK6vyq7fiM5qHnDeKG5edDblm8qEh/K/2Ogn9v1ZEKf2BJQFzpJxy7/sCAciZ0j+hY6SNkWVZIyQiLn9+mVGIEjKdPDadP8lvt8CYE4Y5vGfIKo2Mw5ziCdYHCZ+eiG6m+GK9yqdX4n3je1VffYFSIze5vNbgcdgM/uL9BJgiz3iC4d29ble1Uac8MleObrnScB7MCHuMVevwLdFm8kt+TGMbZ2t/MH/xxsUtTFJH7cjuz3ykZtIzfR+CPTkB3OZ637SunzYUcQ70mFzkk/e8xdLjZeKP1r27j6LQK/D84x2RVqB","salt":"08ddfdcc4abbc7e159e2bbd6773b80c3","path":"1608\'/0\'/632486385\'"}';

  group('Recoverbull Bip85', () {
    for (final path in recoverbullPathWithMissingLastSingleQuote) {
      test('deriveBackupKey', () {
        final derivedKey = RecoverbullBip85Utils.deriveBackupKey(xprv, path);
        expect(derivedKey, expectedKeyForPath);
      });
    }
    test('deriveBackupKey supports the new derivation path', () {
      expect(RecoverbullBip85Utils.deriveBackupKey(xprv, newPath), newPathKey);
    });

    for (final fixture in [oldFixture, newFixture]) {
      test(
        'decrypts encrypted vault fixture ${fixture == oldFixture ? 'old' : 'new'} path',
        () {
          final backup = sdk.BullBackup.fromJson(fixture);
          final bytes = sdk.RecoverBull.restoreBackup(
            backup: backup,
            backupKey: convert.hex.decode(
              fixture == oldFixture ? expectedKeyForPath : newPathKey,
            ),
          );
          final json =
              jsonDecode(String.fromCharCodes(bytes)) as Map<String, dynamic>;
          expect(
            json['mnemonic'],
            List.generate(11, (_) => 'zoo')..add('wrong'),
          );
        },
      );
    }
  });
}
