import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/tor/domain/usecases/initialize_tor_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

import 'package:bb_mobile/features/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final restoreBackupKeyFromPasswordUsecase =
      locator<RestoreBackupKeyFromPasswordUsecase>();

  final initializeTorUsecase = locator<InitializeTorUsecase>();

  final restoreEncryptedVaultFromBackupKeyUsecase =
      locator<RestoreEncryptedVaultFromBackupKeyUsecase>();

  final walletRepository = locator<WalletRepository>();
  final seedRepository = locator<SeedRepository>();

  const backupZooMnemonicWithSevenZerosPassword =
      """{"created_at":1755719049652,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608'/0'/586053381"}""";
  const password = '0000000';
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
    test('Restore backup key from password', () async {
      final backupKey = await restoreBackupKeyFromPasswordUsecase.execute(
        backupFile: backupZooMnemonicWithSevenZerosPassword,
        password: password,
      );

      expect(backupKey, isNotEmpty);
    });

    test('Restore encrypted vault from backup key', () async {
      final backupKey = await restoreBackupKeyFromPasswordUsecase.execute(
        backupFile: backupZooMnemonicWithSevenZerosPassword,
        password: password,
      );
      expect(backupKey, isNotEmpty);

      await restoreEncryptedVaultFromBackupKeyUsecase.execute(
        backupFile: backupZooMnemonicWithSevenZerosPassword,
        backupKey: backupKey,
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
  });
}
