import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';

import 'package:bb_mobile/features/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final initializeTorUsecase = locator<InitTorUsecase>();
  final restoreVaultKeyFromPasswordUsecase =
      locator<RestoreVaultKeyFromPasswordUsecase>();
  final restoreEncryptedVaultFromVaultKeyUsecase =
      locator<RestoreEncryptedVaultFromVaultKeyUsecase>();
  final deriveBackupKeyFromDefaultWalletUsecase =
      locator<DeriveBackupKeyFromDefaultWalletUsecase>();
  final decryptVaultUsecase = locator<DecryptVaultUsecase>();

  final walletRepository = locator<WalletRepository>();
  final seedRepository = locator<SeedRepository>();

  const oldPathZooMnemonicWithSevenZerosPassword =
      """{"created_at":784044000000,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608'/0'/586053381"}""";
  const newPathZooMnemonicWithSevenZerosPassword =
      """{"created_at":1759844619801,"id":"4958a5130b77d4359b88a541998351f04e595060e867e8ea5cd2e8efdc4cddaa","ciphertext":"wBeihGFKLoCQeSZhhX7Nh7zbMzt5If/5QayQ4MuzsQ1X8DgUFo+FbdpPx3KB8Xjwe25DknAc5TIU9zbIDoETIGCWZohvVt1sL5L+bweLVijbJlUQub0va3ZlYSR5QeHVfisaKlS2Psv5mqF9XK6vyq7fiM5qHnDeKG5edDblm8qEh/K/2Ogn9v1ZEKf2BJQFzpJxy7/sCAciZ0j+hY6SNkWVZIyQiLn9+mVGIEjKdPDadP8lvt8CYE4Y5vGfIKo2Mw5ziCdYHCZ+eiG6m+GK9yqdX4n3je1VffYFSIze5vNbgcdgM/uL9BJgiz3iC4d29ble1Uac8MleObrnScB7MCHuMVevwLdFm8kt+TGMbZ2t/MH/xxsUtTFJH7cjuz3ykZtIzfR+CPTkB3OZ637SunzYUcQ70mFzkk/e8xdLjZeKP1r27j6LQK/D84x2RVqB","salt":"08ddfdcc4abbc7e159e2bbd6773b80c3","path":"1608'/0'/632486385'"}""";
  const password = '0000000';
  const oldPathVaultKey =
      '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';
  const newPathVaultKey =
      '32255e6651db67fa5b5a44240b6a5d2189cb58666bcc3830c35aff5a2b01b84f';
  const expectedMnemonicWords = [
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'wrong',
  ];

  setUpAll(() async => await initializeTorUsecase.execute());

  group('Recoverbull', () {
    test('Restore encrypted vault from backup key', () async {
      final vaultKey = await restoreVaultKeyFromPasswordUsecase.execute(
        vault: EncryptedVault(file: oldPathZooMnemonicWithSevenZerosPassword),
        password: password,
      );
      expect(vaultKey, oldPathVaultKey);

      await restoreEncryptedVaultFromVaultKeyUsecase.execute(
        vault: EncryptedVault(file: oldPathZooMnemonicWithSevenZerosPassword),
        vaultKey: vaultKey,
      );

      final wallets = await walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );

      expect(wallets.length, 1);
      final wallet = wallets.first;
      expect(wallet.masterFingerprint, isNotEmpty);
      final seed = await seedRepository.get(wallet.masterFingerprint);
      final seedModel = SeedModel.fromEntity(seed);
      expect(seedModel, isA<MnemonicSeedModel>());
      final mnemonicSeedModel = seedModel as MnemonicSeedModel;
      expect(mnemonicSeedModel.mnemonicWords, equals(expectedMnemonicWords));
    });

    test('Restore key from password (Key Server)', () async {
      final vaultKey = await restoreVaultKeyFromPasswordUsecase.execute(
        vault: EncryptedVault(file: oldPathZooMnemonicWithSevenZerosPassword),
        password: password,
      );
      expect(vaultKey, oldPathVaultKey);
    });

    test('OLD path: Derive key from default wallet', () async {
      final derivedKey = await deriveBackupKeyFromDefaultWalletUsecase.execute(
        vault: EncryptedVault(file: oldPathZooMnemonicWithSevenZerosPassword),
      );
      expect(derivedKey, oldPathVaultKey);
    });

    test('NEW path: Derive key from default wallet', () async {
      final derivedKey = await deriveBackupKeyFromDefaultWalletUsecase.execute(
        vault: EncryptedVault(file: newPathZooMnemonicWithSevenZerosPassword),
      );
      expect(derivedKey, newPathVaultKey);
    });

    test('OLD path: Decrypt vault from key', () {
      final decryptedVault = decryptVaultUsecase.execute(
        vault: EncryptedVault(file: oldPathZooMnemonicWithSevenZerosPassword),
        vaultKey: oldPathVaultKey,
      );
      expect(decryptedVault, isA<DecryptedVault>());
    });

    test('NEW path: Decrypt vault from key', () {
      final decryptedVault = decryptVaultUsecase.execute(
        vault: EncryptedVault(file: newPathZooMnemonicWithSevenZerosPassword),
        vaultKey: newPathVaultKey,
      );
      expect(decryptedVault, isA<DecryptedVault>());
    });
  });
}
