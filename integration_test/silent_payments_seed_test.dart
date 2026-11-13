import 'dart:io';

import 'package:bb_mobile/init.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

const _englishSpAddress =
    'tsp1qqdpels3srq45dlezqvk20t3dlueftry6p5thc7msjm0s6jm3g84jzq5rxzzunfck6d45va2jcqxk429agt3e4klf3vzmcgp3zqthryhhqgnz4k3n';

Future<void> _close(SpAccount account) async {
  await account.dispose();
  await account.release();
  expect(account.isDisposed, isTrue);
}

/// Public, funds-free BIP39 vectors exercise the real native account boundary.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Bull.init();
  late Directory scratch;
  late Secrets secrets;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    scratch = await Directory.systemTemp.createTemp('sp_seed_vectors_');
    secrets = Secrets(scratchDirectory: () async => scratch.path);
  });
  tearDown(() async => scratch.delete(recursive: true));

  testWidgets('BIP39 language and passphrase select the correct SP account', (
    tester,
  ) async {
    final english = bip39.Mnemonic(List.filled(16, 0), bip39.Language.english);
    final french = bip39.Mnemonic(List.filled(16, 0), bip39.Language.french);
    Future<Secret> import(bip39.Mnemonic mnemonic, {String? passphrase}) async {
      final result = await secrets.import(
        words: mnemonic.words,
        language: mnemonic.language,
        passphrase: passphrase,
      );
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Import failed: ${failure.runtimeType}'),
      };
    }

    Future<SpAccount> open(Secret secret, String dir) async {
      final result = await secret.silentPayments.account(
        name: 'vector',
        network: SpNetwork.signet,
        blindbitUrl: 'http://127.0.0.1:1',
        electrumUrl: 'tcp://127.0.0.1:1',
        dataDir: dir,
        dustLimit: BigInt.zero,
        fetchConcurrencyFactor: 1,
        matchConcurrencyFactor: 1,
      );
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => fail('Open failed: ${failure.runtimeType}'),
      };
    }

    final legacy = await SpAccount.createFromMnemonicWithScanRuntime(
      name: 'vector',
      network: SpNetwork.signet,
      mnemonic: english.words.join(' '),
      blindbitUrl: 'http://127.0.0.1:1',
      electrumUrl: 'tcp://127.0.0.1:1',
      dataDir: '${scratch.path}/legacy',
      dustLimit: BigInt.zero,
      fetchConcurrencyFactor: 1,
      matchConcurrencyFactor: 1,
    );
    final legacyAddress = legacy.spAddress();
    expect(legacyAddress == _englishSpAddress, isTrue);
    await _close(legacy);

    final englishSecret = await import(english);
    final englishAccount = await open(englishSecret, '${scratch.path}/english');
    expect(englishAccount.spAddress() == legacyAddress, isTrue);
    await _close(englishAccount);
    final reopened = await open(englishSecret, '${scratch.path}/english');
    expect(reopened.spAddress() == legacyAddress, isTrue);
    await _close(reopened);

    final frenchAccount = await open(
      await import(french),
      '${scratch.path}/fr',
    );
    final frenchAddress = frenchAccount.spAddress();
    await _close(frenchAccount);
    final passphraseAccount = await open(
      await import(english, passphrase: 'TREZOR'),
      '${scratch.path}/passphrase',
    );
    final passphraseAddress = passphraseAccount.spAddress();
    await _close(passphraseAccount);
    expect({legacyAddress, frenchAddress, passphraseAddress}, hasLength(3));
  });
}
