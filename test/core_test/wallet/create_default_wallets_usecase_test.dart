import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Inventory extends Mock implements WalletInventory {}

void main() {
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _Inventory inventory;
  late List<WalletRegistration> registrations;
  late List<Network> created;
  late Network? failNetwork;
  late DefaultWalletProvisioning provisioning;

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    inventory = _Inventory();
    registrations = [];
    created = [];
    failNetwork = null;
    registerFallbackValue(BitcoinNetwork.mainnet);
    when(() => inventory.walletsForNetwork(any())).thenAnswer((
      invocation,
    ) async {
      final network = invocation.positionalArguments.single as Network;
      return Ok(
        walletSelectionForTesting(
          registrations.where((wallet) => wallet.network == network).toList(),
        ),
      );
    });
    when(() => inventory.readWallet(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return Ok(registrations.singleWhere((wallet) => wallet.id == id));
    });
    provisioning = DefaultWalletProvisioning(
      secrets: secrets,
      inventory: inventory,
      environment: () async => NetworkEnv.mainnet,
      resume: () async {},
      create: (secret, network, birthday) async {
        created.add(network);
        if (network == failNetwork) {
          failNetwork = null;
          throw Exception('temporary failure');
        }
        final id = network.toString();
        registrations.add(
          walletRegistrationForTesting(
            id: id,
            network: network,
            signer: WalletSigner.local,
            isDefault: true,
            masterFingerprint: secret.id,
            secretFingerprint: secret.id,
          ),
        );
        return id;
      },
    );
  });

  test('returns committed defaults with the same local secret', () async {
    final result = await provisioning.execute();
    expect(result, isA<Ok<List<WalletRegistration>, DefaultWalletFailure>>());
    final wallets =
        (result as Ok<List<WalletRegistration>, DefaultWalletFailure>).value;
    expect(wallets.map((wallet) => wallet.network), [
      BitcoinNetwork.mainnet,
      LiquidNetwork.mainnet,
    ]);
    expect(wallets.first.secretFingerprint, wallets.last.secretFingerprint);
    expect(created, [BitcoinNetwork.mainnet, LiquidNetwork.mainnet]);
  });

  test(
    'incomplete inventory prevents secret generation and account creation',
    () async {
      when(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet))
          .thenAnswer(
            (_) async => Ok(walletSelectionForTesting([], isComplete: false)),
          );
      final result = await provisioning.execute();
      expect(
        result,
        isA<Err<List<WalletRegistration>, DefaultWalletFailure>>(),
      );
      expect((result as Err).failure, isA<DefaultWalletStorageFailure>());
      expect(created, isEmpty);
      expect(storage.entries, isEmpty);
    },
  );

  for (final failedNetwork in [BitcoinNetwork.mainnet, LiquidNetwork.mainnet]) {
    test('restoration resumes after failure on $failedNetwork', () async {
      final words = [...List.filled(11, 'abandon'), 'about'];
      failNetwork = failedNetwork;
      final first = await provisioning.execute(
        mnemonicWords: words,
        language: Language.english,
      );
      expect((first as Err).failure, isA<DefaultWalletCreationFailure>());
      final before = Map<String, String>.of(storage.entries);
      final recovered = await provisioning.execute(
        mnemonicWords: words,
        language: Language.english,
      );
      final wallets =
          (recovered as Ok<List<WalletRegistration>, DefaultWalletFailure>)
              .value;
      expect(wallets.map((wallet) => wallet.network), [
        BitcoinNetwork.mainnet,
        LiquidNetwork.mainnet,
      ]);
      expect(wallets.first.secretFingerprint, wallets.last.secretFingerprint);
      expect(storage.entries, before);
      if (failedNetwork == LiquidNetwork.mainnet) {
        expect(
          created.where((network) => network == BitcoinNetwork.mainnet),
          hasLength(1),
        );
      }
    });
  }

  for (final candidate in ['', 'incorrect', 'synthetic-passphrase']) {
    test(
      'partial protected defaults require the matching passphrase $candidate',
      () async {
        final words = [...List.filled(11, 'abandon'), 'about'];
        final secret = (await secrets.import(
          words: words,
          language: Language.english,
          passphrase: 'synthetic-passphrase',
        ) as Ok<Secret, SecretFailure>).value;
        registrations.add(
          walletRegistrationForTesting(
            id: 'bitcoin',
            network: BitcoinNetwork.mainnet,
            isDefault: true,
            signer: WalletSigner.local,
            masterFingerprint: secret.id,
            secretFingerprint: secret.id,
          ),
        );
        final before = Map<String, String>.of(storage.entries);
        final result = await provisioning.execute(
          mnemonicWords: words,
          language: Language.english,
          passphrase: candidate,
        );
        if (candidate == 'synthetic-passphrase') {
          expect(
            (result as Ok<List<WalletRegistration>, DefaultWalletFailure>)
                .value,
            hasLength(2),
          );
          expect(created, [LiquidNetwork.mainnet]);
        } else {
          expect(
            (result as Err).failure,
            isA<DefaultWalletAlreadyExistsFailure>(),
          );
          expect(created, isEmpty);
        }
        expect(storage.entries, before);
      },
    );
  }

  test(
    'a partial setup with unavailable custody never generates a replacement',
    () async {
      final fingerprint = Fingerprint('deadbeef');
      registrations.add(
        walletRegistrationForTesting(
          id: 'bitcoin',
          network: BitcoinNetwork.mainnet,
          isDefault: true,
          signer: WalletSigner.local,
          masterFingerprint: fingerprint,
          secretFingerprint: fingerprint,
        ),
      );
      final result = await provisioning.execute();
      expect((result as Err).failure, isA<DefaultWalletSecretFailure>());
      expect(storage.entries, isEmpty);
      expect(created, isEmpty);
    },
  );

  test('complete defaults are reused without custody access and cannot be restored over', () async {
    final fingerprint = Fingerprint('deadbeef');
    for (final network in [BitcoinNetwork.mainnet, LiquidNetwork.mainnet]) {
      registrations.add(
        walletRegistrationForTesting(
          id: network.toString(),
          network: network,
          isDefault: true,
          signer: WalletSigner.local,
          masterFingerprint: fingerprint,
          secretFingerprint: fingerprint,
        ),
      );
    }
    final reads = storage.reads;
    expect((await provisioning.execute() as Ok).value, registrations);
    expect(
      (await provisioning.execute(
        mnemonicWords: [...List.filled(11, 'abandon'), 'about'],
        language: Language.english,
      ) as Err).failure,
      isA<DefaultWalletAlreadyExistsFailure>(),
    );
    expect(storage.reads, reads);
    expect(created, isEmpty);
  });

  test(
    'invalid recovery arguments fail before reading the inventory',
    () async {
      await expectLater(
        provisioning.execute(passphrase: 'phrase'),
        throwsArgumentError,
      );
      await expectLater(
        provisioning.execute(mnemonicWords: ['abandon']),
        throwsArgumentError,
      );
      await expectLater(
        provisioning.execute(language: Language.english),
        throwsArgumentError,
      );
      verifyZeroInteractions(inventory);
    },
  );

  test(
    'environment mismatch refuses before resuming or custody writes',
    () async {
      var resumed = false;
      final fenced = DefaultWalletProvisioning(
        secrets: secrets,
        inventory: inventory,
        environment: () async => NetworkEnv.mainnet,
        resume: () async {
          resumed = true;
        },
        create: (_, _, _) async => fail('creation should not start'),
      );
      final result = await fenced.execute(expectedNetwork: NetworkEnv.regtest);
      expect(
        (result as Err).failure,
        isA<DefaultWalletNetworkChangedFailure>(),
      );
      expect(resumed, isFalse);
      expect(storage.entries, isEmpty);
      verifyZeroInteractions(inventory);
    },
  );

  test('non-English mnemonic retains its language when restoring', () async {
    final words = [...List.filled(11, 'あいこくしん'), 'あおぞら'];
    final result = await provisioning.execute(
      mnemonicWords: words,
      language: Language.japanese,
    );
    final wallets =
        (result as Ok<List<WalletRegistration>, DefaultWalletFailure>).value;
    final loaded = await secrets.fetch(
      wallets.first.secretFingerprint as Fingerprint,
    );
    expect(
      (loaded as Ok<Secret, SecretFailure>).value.info.language,
      Language.japanese,
    );
    expect(wallets.first.secretFingerprint, wallets.last.secretFingerprint);
  });

  test('a seed-only secret is refused before inventory access', () async {
    storage.entries['seed_3442193e'] = '{"bytes":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],"runtimeType":"bytes"}';
    final secret = (await secrets.fetch(
      Fingerprint('3442193e'),
    ) as Ok<Secret, SecretFailure>).value;
    final result = await provisioning.execute(secret: secret);
    expect(
      (result as Err).failure,
      isA<DefaultWalletMnemonicRequiredFailure>(),
    );
    verifyZeroInteractions(inventory);
  });

  test('a different secret cannot replace a partial default', () async {
    final secret = (await secrets.import(
      words: [...List.filled(11, 'abandon'), 'about'],
      language: Language.english,
    ) as Ok<Secret, SecretFailure>).value;
    final existing = Fingerprint('deadbeef');
    registrations.add(
      walletRegistrationForTesting(
        id: 'bitcoin',
        network: BitcoinNetwork.mainnet,
        isDefault: true,
        signer: WalletSigner.local,
        masterFingerprint: existing,
        secretFingerprint: existing,
      ),
    );
    final before = Map<String, String>.of(storage.entries);
    expect(
      (await provisioning.execute(secret: secret) as Err).failure,
      isA<DefaultWalletAlreadyExistsFailure>(),
    );
    expect(storage.entries, before);
    expect(created, isEmpty);
  });

  test(
    'regtest resumes native provisioning before reading or creating accounts',
    () async {
      var resumed = false;
      final regtest = DefaultWalletProvisioning(
        secrets: secrets,
        inventory: inventory,
        environment: () async => NetworkEnv.regtest,
        resume: () async {
          resumed = true;
        },
        create: (secret, network, birthday) async {
          expect(resumed, isTrue);
          created.add(network);
          final id = network.toString();
          registrations.add(
            walletRegistrationForTesting(
              id: id,
              network: network,
              signer: WalletSigner.local,
              isDefault: true,
              masterFingerprint: secret.id,
              secretFingerprint: secret.id,
            ),
          );
          return id;
        },
      );
      expect(
        await regtest.execute(expectedNetwork: NetworkEnv.regtest),
        isA<Ok>(),
      );
      expect(created, [BitcoinNetwork.regtest, LiquidNetwork.regtest]);
    },
  );

  test(
    'repair refuses a public-only fingerprint as a secret reference',
    () async {
      var created = false;
      final repair = DefaultWalletRepair(secrets, (_, _) async {
        created = true;
      });
      final result = await repair.execute(
        [
          walletRegistrationForTesting(
            id: 'watch-only',
            network: BitcoinNetwork.mainnet,
            isDefault: true,
            signer: WalletSigner.none,
            masterFingerprint: Fingerprint('deadbeef'),
          ),
        ],
        bitcoin: BitcoinNetwork.mainnet,
        liquid: LiquidNetwork.mainnet,
      );
      expect(result, isA<Err<bool, ProvisioningFailure>>());
      expect(created, isFalse);
      expect(storage.entries, isEmpty);
    },
  );
}
