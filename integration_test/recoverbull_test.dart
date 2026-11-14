import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'dart:io';

import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/init.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final recoverbull = locator<RecoverBullFacade>();

  final walletRepository = locator<WalletRepository>();
  final secrets = locator<custody.Secrets>();

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
  // The restore test calls the production key server over Tor, so an outage
  // there would fail every PR. In CI it runs only on PRs to main and manual
  // runs; local runs always exercise it.
  final runLiveKeyServerTest =
      Platform.environment['CI'] != 'true' ||
      Platform.environment['RUN_LIVE_KEYSERVER_TEST'] == 'true';

  group('Recoverbull', () {
    // Fetches the vault key over Tor from the RecoverBull key server. Tor can
    // take ~20s to bootstrap before the first request even goes out, so the
    // default 30s test timeout is too tight — give it a full minute.
    test(
      'Restore encrypted vault',
      timeout: const Timeout(Duration(minutes: 2)),
      skip: runLiveKeyServerTest
          ? false
          : 'calls the production key server: runs on PRs to main or a manually dispatched CI run',
      () async {
        final settings = await recoverbull.settings();
        expect(settings, isA<Ok<BackupSettings, RecoverBullFailure>>());
        final server =
            (settings as Ok<BackupSettings, RecoverBullFailure>).value.server;
        expect(await recoverbull.acceptServer(server), isA<Ok>());
        final parsed = recoverbull.parseVault(
          oldPathZooMnemonicWithSevenZerosPassword,
        );
        expect(parsed, isA<Ok<EncryptedVault, RecoverBullFailure>>());
        final restored = await recoverbull.recoverFromServer(
          vault: (parsed as Ok<EncryptedVault, RecoverBullFailure>).value,
          password: password,
        );
        expect(restored, isA<Ok<VaultCompletion, RecoverBullFailure>>());
        final completion =
            (restored as Ok<VaultCompletion, RecoverBullFailure>).value;
        expect(completion.recovery, isA<VaultRecovered>());
        expect(completion.warning, isNull);
        expect(completion.verifiedContext?.network, BitcoinNetwork.mainnet);

        final walletsResult = await walletRepository.getWallets(
          onlyDefaults: true,
          onlyBitcoin: true,
          environment: Environment.mainnet,
        );

        expect(walletsResult, isA<Ok<List<Wallet>, WalletFailure>>());
        final wallets =
            (walletsResult as Ok<List<Wallet>, WalletFailure>).value;
        expect(wallets.length, 1);
        final wallet = wallets.first;
        expect(wallet.masterFingerprint, isNotEmpty);
        final secret = switch (await secrets.fetch(
          Fingerprint(wallet.masterFingerprint),
        )) {
          Ok(:final value) => value,
          Err(:final failure) => fail('fetch failed: ${failure.runtimeType}'),
        };
        // `verify.mnemonic` compares inside the package and returns only the verdict: the restored words are never read back out to be asserted on.
        expect(switch (await secret.verify.mnemonic(expectedMnemonicWords)) {
          Ok(:final value) => value,
          Err(:final failure) => fail('verify failed: ${failure.runtimeType}'),
        }, isTrue);
      },
    );

    test('OLD path: Inspect vault from key without restoring', () async {
      final result = await secrets.recoverbull.fingerprint(
        vault: custody.EncryptedVault(
          json: oldPathZooMnemonicWithSevenZerosPassword,
        ),
        key: custody.VaultKey(oldPathVaultKey),
      );
      expect(
        result,
        isA<Ok<Fingerprint, custody.SecretFailure>>().having(
          (result) => result.value.hex,
          'fingerprint derived from the vault words',
          '3f635a63',
        ),
      );
    });

    test('NEW path: Inspect vault from key without restoring', () async {
      final result = await secrets.recoverbull.fingerprint(
        vault: custody.EncryptedVault(
          json: newPathZooMnemonicWithSevenZerosPassword,
        ),
        key: custody.VaultKey(newPathVaultKey),
      );
      expect(
        result,
        isA<Ok<Fingerprint, custody.SecretFailure>>().having(
          (result) => result.value.hex,
          'fingerprint derived from the vault words',
          '3f635a63',
        ),
      );
    });
  });
}
