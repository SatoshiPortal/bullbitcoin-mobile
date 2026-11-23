import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart' show ActiveEnvironmentReader;
import 'package/primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart' show SyncFailure;

/// Answers the active environment; provisioning must read it exactly once.
final class _Environment implements ActiveEnvironmentReader {
  _Environment(this.environment);

  final NetworkEnv environment;
  int reads = 0;

  @override
  Future<Result<Environment, PreferencesFailure>> readActiveEnvironment() async {
    reads++;
    return Ok(Environment.values.byName(environment.name));
  }
}

/// The provisioning contract, without an inventory: records what the pair was
/// asked to create and lets a test take custody of the committed rows.
final class _Accounts implements WalletProvisioning {
  final List<Network> created = [];
  int resumes = 0;
  int reads = 0;
  Network? failNetwork;
  void Function(Secret secret, Network network)? onCreate;

  @override
  Future<Result<void, WalletProvisioningFailure>> resume() async {
    resumes++;
    return const Ok(null);
  }

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    Network network, {
    DateTime? birthday,
  }) async {
    created.add(network);
    if (network == failNetwork) {
      failNetwork = null;
      throw Exception('temporary failure');
    }
    onCreate?.call(secret, network);
    return Ok(network.toString());
  }

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) async => throw UnimplementedError('default setup imports no mnemonic');

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) async => throw UnimplementedError('default setup imports no descriptor');

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) async => throw UnimplementedError('default setup imports no xpub');
}

/// The inventory reads the pair performs, counted for "no access" assertions.
final class _Inventory implements WalletInventory {
  final List<WalletRegistration> registrations = [];
  final Set<Network> incomplete = {};
  int reads = 0;

  @override
  Future<Result<List<Fingerprint>, SecretFailure>> referencedFingerprints() async {
    reads++;
    return Ok(const <Fingerprint>[]);
  }

  @override
  Future<Result<WalletRegistration, SecretFailure>> readWallet(String id) async {
    reads++;
    return Ok(registrations.singleWhere((wallet) => wallet.id == id));
  }

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async {
    reads++;
    return Ok(
      walletSelectionForTesting(
        registrations.where((wallet) => wallet.network == network).toList(),
        isComplete: !incomplete.contains(network),
      ),
    );
  }
}

void main() {
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _Inventory inventory;
  late _Accounts accounts;
  late _Environment environment;
  late List<WalletRegistration> registrations;
  late DefaultWalletProvisioning provisioning;

  void addWallet(Secret secret, Network network) {
    registrations.add(
      walletRegistrationForTesting(
        id: network.toString(),
        network: network,
        signer: WalletSigner.local,
        isDefault: true,
        masterFingerprint: secret.id,
        secretFingerprint: secret.id,
      ),
    );
  }

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => '/tmp');
    inventory = _Inventory();
    accounts = _Accounts();
    environment = _Environment(NetworkEnv.mainnet);
    registrations = inventory.registrations;
    accounts.onCreate = (secret, network) {
      addWallet(secret, network);
      inventory.registrations.add(
        walletRegistrationForTesting(
          id: network.toString(),
          network: network,
          signer: WalletSigner.local,
          isDefault: true,
          masterFingerprint: secret.id,
          secretFingerprint: secret.id,
        ),
      );
    };
    provisioning = DefaultWalletProvisioning(
      secrets: secrets,
      inventory: inventory,
      environment: environment,
      accounts: accounts,
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
    expect(accounts.created, [BitcoinNetwork.mainnet, LiquidNetwork.mainnet]);
    expect(accounts.resumes, 1);
  });

  test(
    'incomplete inventory prevents secret generation and account creation',
    () async {
      inventory.incomplete.add(BitcoinNetwork.mainnet);
      final result = await provisioning.execute();
      expect(
        result,
        isA<Err<List<WalletRegistration>, DefaultWalletFailure>>(),
      );
      expect((result as Err).failure, isA<DefaultWalletStorageFailure>());
      expect(accounts.created, isEmpty);
      expect(storage.entries, isEmpty);
    },
  );

  for (final failedNetwork in <Network>[
    BitcoinNetwork.mainnet,
    LiquidNetwork.mainnet,
  ]) {
    test('restoration resumes after failure on $failedNetwork', () async {
      final words = [...List.filled(11, 'abandon'), 'about'];
      accounts.failNetwork = failedNetwork;
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
          accounts.created.where((network) => network == BitcoinNetwork.mainnet),
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
        inventory.registrations.add(
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
          expect(accounts.created, [LiquidNetwork.mainnet]);
        } else {
          expect(
            (result as Err).failure,
            isA<DefaultWalletAlreadyExistsFailure>(),
          );
          expect(accounts.created, isEmpty);
        }
        expect(storage.entries, before);
      },
    );
  }

  test(
    'a partial setup with unavailable custody never generates a replacement',
    () async {
      final fingerprint = Fingerprint('deadbeef');
      inventory.registrations.add(
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
      expect(accounts.created, isEmpty);
    },
  );

  test(
    'complete defaults are reused without custody access and cannot be restored over',
    () async {
      final fingerprint = Fingerprint('deadbeef');
      for (final network in <Network>[
        BitcoinNetwork.mainnet,
        LiquidNetwork.mainnet,
      ]) {
        inventory.registrations.add(
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
      expect(
        (await provisioning.execute() as Ok).value,
        inventory.registrations,
      );
      expect(
        (await provisioning.execute(
          mnemonicWords: [...List.filled(11, 'abandon'), 'about'],
          language: Language.english,
        ) as Err).failure,
        isA<DefaultWalletAlreadyExistsFailure>(),
      );
      expect(storage.reads, reads);
      expect(accounts.created, isEmpty);
    },
  );

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
      expect(inventory.reads, 0);
      expect(environment.reads, 0);
      expect(accounts.resumes, 0);
    },
  );

  test(
    'environment mismatch refuses before resuming or custody writes',
    () async {
      final fenced = DefaultWalletProvisioning(
        secrets: secrets,
        inventory: inventory,
        environment: _Environment(NetworkEnv.mainnet),
        accounts: accounts,
      );
      final result = await fenced.execute(expectedNetwork: NetworkEnv.regtest);
      expect(
        (result as Err).failure,
        isA<DefaultWalletNetworkChangedFailure>(),
      );
      expect(accounts.resumes, 0);
      expect(storage.entries, isEmpty);
      expect(inventory.reads, 0);
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
    storage.entries['seed_3442193e'] =
        '{"bytes":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],"runtimeType":"bytes"}';
    final secret = (await secrets.fetch(
      Fingerprint('3442193e'),
    ) as Ok<Secret, SecretFailure>).value;
    final result = await provisioning.execute(secret: secret);
    expect(
      (result as Err).failure,
      isA<DefaultWalletMnemonicRequiredFailure>(),
    );
    expect(inventory.reads, 0);
    expect(accounts.resumes, 0);
  });

  test('a different secret cannot replace a partial default', () async {
    final secret = (await secrets.import(
      words: [...List.filled(11, 'abandon'), 'about'],
      language: Language.english,
    ) as Ok<Secret, SecretFailure>).value;
    final existing = Fingerprint('deadbeef');
    inventory.registrations.add(
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
    expect(accounts.created, isEmpty);
  });

  test(
    'regtest resumes native provisioning before reading or creating accounts',
    () async {
      final regtest = DefaultWalletProvisioning(
        secrets: secrets,
        inventory: inventory,
        environment: _Environment(NetworkEnv.regtest),
        accounts: accounts,
      );
      accounts.onCreate = (secret, network) {
        expect(accounts.resumes, 1, reason: 'resume precedes creation');
        addWallet(secret, network);
      };
      expect(
        await regtest.execute(expectedNetwork: NetworkEnv.regtest),
        isA<Ok>(),
      );
      expect(accounts.created, [
        BitcoinNetwork.regtest,
        LiquidNetwork.regtest,
      ]);
    },
  );

  test(
    'repair refuses a public-only fingerprint as a secret reference',
    () async {
      final repair = DefaultWalletRepair(secrets, accounts);
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
      expect(accounts.created, isEmpty);
      expect(storage.entries, isEmpty);
    },
  );
}
