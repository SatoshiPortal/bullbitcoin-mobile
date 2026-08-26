import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final feature = locator<RecoverBullFeature>();
  final walletRepository = locator<WalletRepository>();
  final seedRepository = locator<SeedRepository>();

  const oldPathVault =
      '{"created_at":784044000000,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608\'/0\'/586053381"}';
  const newPathVault =
      '{"created_at":1759844619801,"id":"4958a5130b77d4359b88a541998351f04e595060e867e8ea5cd2e8efdc4cddaa","ciphertext":"wBeihGFKLoCQeSZhhX7Nh7zbMzt5If/5QayQ4MuzsQ1X8DgUFo+FbdpPx3KB8Xjwe25DknAc5TIU9zbIDoETIGCWZohvVt1sL5L+bweLVijbJlUQub0va3ZlYSR5QeHVfisaKlS2Psv5mqF9XK6vyq7fiM5qHnDeKG5edDblm8qEh/K/2Ogn9v1ZEKf2BJQFzpJxy7/sCAciZ0j+hY6SNkWVZIyQiLn9+mVGIEjKdPDadP8lvt8CYE4Y5vGfIKo2Mw5ziCdYHCZ+eiG6m+GK9yqdX4n3je1VffYFSIze5vNbgcdgM/uL9BJgiz3iC4d29ble1Uac8MleObrnScB7MCHuMVevwLdFm8kt+TGMbZ2t/MH/xxsUtTFJH7cjuz3ykZtIzfR+CPTkB3OZ637SunzYUcQ70mFzkk/e8xdLjZeKP1r27j6LQK/D84x2RVqB","salt":"08ddfdcc4abbc7e159e2bbd6773b80c3","path":"1608\'/0\'/632486385\'"}';
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

  group('RecoverBull', () {
    test(
      'restores the funded old vault through Tor and the key server',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        debugPrint('''

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║   ⏳  HEADS UP — THIS TEST IS SLOW (up to ~2 MINUTES). NOT FROZEN.         ║
║                                                                            ║
║   It fetches the vault key over Tor from the RecoverBull key server.       ║
║   Tor needs ~20s just to bootstrap, then the key-server round-trip can     ║
║   take a while. Sit tight — go grab a coffee. ☕                           ║
║                                                                            ║
╚══════════════════════════════════════════════════════════════════════════╝
''');
        expect(await feature.ensureTorReady(), isTrue);
        final result = await feature.recoverBackup(
          encryptedBackup: oldPathVault,
          password: password,
        );
        expect(result.restored, isTrue);

        final wallets = await walletRepository.getWallets(
          onlyDefaults: true,
          onlyBitcoin: true,
          environment: Environment.mainnet,
        );
        expect(wallets, hasLength(1));
        final wallet = wallets.single;
        expect(wallet.masterFingerprint, isNotEmpty);
        final seed = await seedRepository.get(wallet.masterFingerprint);
        final seedModel = SeedModel.fromEntity(seed);
        expect(seedModel, isA<MnemonicSeedModel>());
        expect(
          (seedModel as MnemonicSeedModel).mnemonicWords,
          expectedMnemonicWords,
        );
      },
    );

    test('accepts the old derivation-path vault fixture', () {
      final vault = EncryptedVault(file: oldPathVault);
      expect(vault.derivationPath, "m/1608'/0'/586053381");
    });

    test('accepts the new derivation-path vault fixture', () {
      final vault = EncryptedVault(file: newPathVault);
      expect(vault.derivationPath, "1608'/0'/632486385'");
    });
  });
}
