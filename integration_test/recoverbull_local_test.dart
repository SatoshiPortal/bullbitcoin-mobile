import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<void> main({bool isInitialized = false}) async {
  const enabled = bool.fromEnvironment('BULL_LOCAL_RECOVERY_TEST');
  TestWidgetsFlutterBinding.ensureInitialized();
  if (enabled && !isInitialized) await Bull.init();

  test(
    'restores locally, repeats safely and rejects an unrelated seed',
    () async {
      // Run separately on a fresh, disposable app installation. Refuse to
      // clear an existing wallet or reuse an already-stored fixture seed.
      final wallets = locator<WalletRepository>();
      final seeds = locator<SeedRepository>();
      final restore = locator<RestoreVaultUsecase>();
      final words = [...List.filled(11, 'abandon'), 'about'];
      final fingerprint = seeds.fingerprintFor(mnemonicWords: words);
      expect(await wallets.getStoredWalletIds(), isEmpty);
      expect(await seeds.exists(fingerprint), isFalse);

      final result = await restore.execute(
        decryptedVault: DecryptedVault(mnemonic: words),
      );
      expect(result, isA<Ok<List<String>, RecoverBullCoreFailure>>());
      final created =
          (result as Ok<List<String>, RecoverBullCoreFailure>).value;
      final recovered = await wallets.getWallets(onlyDefaults: true);
      expect(recovered, hasLength(2));
      expect(recovered.where((wallet) => wallet.isBitcoin), hasLength(1));
      expect(recovered.where((wallet) => wallet.isLiquid), hasLength(1));
      expect(created, unorderedEquals(recovered.map((wallet) => wallet.id)));
      expect(created.toSet(), await wallets.getStoredWalletIds());
      expect(
        recovered.every((wallet) => wallet.latestEncryptedBackup != null),
        isTrue,
      );
      for (final wallet in recovered) {
        expect(wallet.singleLocalSeedFingerprint, fingerprint);
      }
      final storedSeed = await seeds.get(fingerprint);
      expect(storedSeed, isA<MnemonicSeed>());
      expect((storedSeed as MnemonicSeed).mnemonicWords, words);
      expect(storedSeed.passphrase, anyOf(isNull, isEmpty));

      final repeated = await restore.execute(
        decryptedVault: DecryptedVault(mnemonic: words),
      );
      expect(repeated, isA<Ok<List<String>, RecoverBullCoreFailure>>());
      expect(
        (repeated as Ok<List<String>, RecoverBullCoreFailure>).value,
        isEmpty,
      );
      expect(await wallets.getStoredWalletIds(), created.toSet());
      expect(
        (await seeds.get(fingerprint) as MnemonicSeed).mnemonicWords,
        words,
      );

      final beforeUnrelatedRestore = await wallets.getWallets(
        onlyDefaults: true,
      );
      final unrelatedWords = [...List.filled(11, 'zoo'), 'wrong'];
      final unrelatedFingerprint = seeds.fingerprintFor(
        mnemonicWords: unrelatedWords,
      );
      expect(await seeds.exists(unrelatedFingerprint), isFalse);
      final unrelated = await restore.execute(
        decryptedVault: DecryptedVault(mnemonic: unrelatedWords),
      );
      expect(unrelated, isA<Err<List<String>, RecoverBullCoreFailure>>());
      expect(
        (unrelated as Err<List<String>, RecoverBullCoreFailure>).failure,
        isA<InvalidVaultFileFailure>(),
      );
      expect(await wallets.getStoredWalletIds(), created.toSet());
      expect(await seeds.exists(unrelatedFingerprint), isFalse);
      final afterUnrelatedRestore = await wallets.getWallets(
        onlyDefaults: true,
      );
      expect(
        {
          for (final wallet in afterUnrelatedRestore)
            wallet.id: wallet.latestEncryptedBackup,
        },
        {
          for (final wallet in beforeUnrelatedRestore)
            wallet.id: wallet.latestEncryptedBackup,
        },
      );
    },
    skip: enabled
        ? null
        : 'Requires a fresh disposable installation and BULL_LOCAL_RECOVERY_TEST=true',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
