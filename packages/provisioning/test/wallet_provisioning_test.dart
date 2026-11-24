import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:satoshifier/bip32_derivation.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart' show SyncFailure, SyncStorageFailure;

import 'support/fakes.dart';
import 'support/inventory_fixture.dart';

// Published BIP39 test-vector account (abandon … about), never funded.
const _words = [
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'about',
];

const _fingerprint = '73c5da0a';
const _bip84MainnetId = 'wpkh([$_fingerprint/84h/0h/0h])';

/// An xpub-only import carries no master fingerprint, so `importXpub` keys its
/// catalog row on the imported account key's own fingerprint — `fd13aac9` for
/// the test vector's BIP84 mainnet account, the same value
/// `wallet_identity_pins_test.dart` pins as `xpubFingerprint` — exactly as the
/// parent `WalletMetadataService.deriveFromXpub` did, with an empty stored
/// master fingerprint.
const _bip84MainnetWatchOnlyId = 'wpkh([fd13aac9/84h/0h/0h])';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late InventoryFixture fixture;
  late Secrets secrets;
  late Secret secret;
  late String xpub;
  late FakeNativeLifecycle native;
  late FakeAdmission admission;
  late WalletProvisioning accounts;

  Future<String> deriveXpub(
    Secret secret,
    Network network,
    ScriptType scriptType,
  ) async => switch (await secret.derive.xpub(
    network: network,
    scriptType: scriptType,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => fail('xpub derivation: $failure'),
  };

  Future<({String external, String internal})> bitcoinDescriptors(
    Secret secret,
    BitcoinNetwork network,
    ScriptType scriptType,
  ) async => switch (await secret.derive.descriptors.bitcoin(
    network: network,
    scriptType: scriptType,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => fail('descriptor derivation: $failure'),
  };

  Future<WatchOnlyAccount> watchOnly(Secret secret) async {
    final descriptors = await bitcoinDescriptors(
      secret,
      BitcoinNetwork.mainnet,
      ScriptType.bip84,
    );
    return WatchOnlyAccount(
      network: BitcoinNetwork.mainnet,
      scriptType: ScriptType.bip84,
      masterFingerprint: secret.id.hex,
      pubkey: await deriveXpub(
        secret,
        BitcoinNetwork.mainnet,
        ScriptType.bip84,
      ),
      descriptors: (
        external: descriptors.external,
        internal: descriptors.internal,
      ),
      signer: SignerEntity.remote,
      signerDevice: 'Coldcard',
      label: 'Reviewed wallet',
    );
  }

  Future<List<RegisteredWallet>> rows() async =>
      switch (await fixture.inventory.listWallets()) {
        Ok(:final value) => value,
        Err(:final failure) => fail('listWallets: $failure'),
      };

  Future<RegisteredWallet> singleRow() async {
    final listed = await rows();
    expect(listed, hasLength(1));
    return listed.single;
  }

  Future<List<String>> loggedLines(String level) async => [
    for (final line in await log.readLogs())
      if (line.split('\t').length > 2 && line.split('\t')[1] == level)
        line.split('\t')[2],
  ];

  setUp(() async {
    FakeSecureStoragePlatform().install();
    directory = await Directory.systemTemp.createTemp('wallet-provisioning-');
    log = Logger.replace(directory: directory);
    secrets = Secrets(scratchDirectory: () async => directory.path);
    secret = switch (await secrets.import(
      words: _words,
      language: Language.english,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => fail('secret import: $failure'),
    };
    expect(secret.id.hex, _fingerprint);
    xpub = await deriveXpub(secret, BitcoinNetwork.mainnet, ScriptType.bip84);
    expect(
      Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
      'fd13aac9',
      reason: 'the xpub import identifies the account key, not the master key',
    );
    fixture = await InventoryFixture.open(directory);
    native = FakeNativeLifecycle();
    admission = FakeAdmission();
    accounts = WalletProvisioning.open(
      inventory: fixture.inventory,
      native: native,
      resume: () async => const Ok(null),
      properties: const [],
    );
  });

  tearDown(() async {
    await fixture.close();
    await log.flush();
    await directory.delete(recursive: true);
  });

  Future<Result<String, WalletProvisioningFailure>> createSecret() =>
      accounts.createDefault(secret, BitcoinNetwork.mainnet);

  Future<Result<void, WalletProvisioningFailure>> createDescriptor() async =>
      accounts.importDescriptor(await watchOnly(secret));

  Future<Result<void, WalletProvisioningFailure>> createXpub() =>
      accounts.importXpub(
        xpub: xpub,
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
        label: 'import',
      );

  group('creation', () {
    test(
      'an independent inventory write commits during native prepare',
      () async {
        final observer = await fixture.openSecond();
        addTearDown(observer.close);
        native.onPrepare = (key) async {
          expect(
            await observer.inventory.setBackgroundEnabled(true),
            isA<Ok<void, SecretFailure>>(),
          );
          return const Ok(null);
        };
        expect(
          await createSecret(),
          isA<Ok<String, WalletProvisioningFailure>>(),
        );
        expect(native.created, hasLength(1));
      },
    );

    test(
      'an independent inventory write commits during native create',
      () async {
        final observer = await fixture.openSecond();
        addTearDown(observer.close);
        native.onCreate = (key) async {
          expect(
            await observer.inventory.setBackgroundEnabled(true),
            isA<Ok<void, SecretFailure>>(),
          );
          return const Ok(null);
        };
        final created = await createSecret();
        expect(created, isA<Ok<String, WalletProvisioningFailure>>());
      },
    );

    test('creating the default account returns its committed id without '
        'advancing addresses', () async {
      final created = await createSecret();
      final id = (created as Ok<String, WalletProvisioningFailure>).value;
      final row = await singleRow();
      expect(row.id, id);
      expect(row.id, _bip84MainnetId);
      expect(row.network, 'bitcoinMainnet');
      expect(row.isDefault, isTrue);
      expect(row.label, 'Secure Bitcoin');
      expect(row.signer, 'local');
      expect(row.masterFingerprint, _fingerprint);
      expect(row.secretFingerprint, _fingerprint);
      expect(native.created.single.id, id);
      expect(native.receiveCalls, 0);
      expect(native.issuedReceiveCalls, 0);
    });

    test('an existing wallet survives a rejected creation', () async {
      expect(
        await accounts.importMnemonic(
          parent: secret.id,
          secrets: secrets,
          admission: admission,
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
          label: 'original',
        ),
        isA<Ok<void, ParentCustodyFailure>>(),
      );
      final before = await singleRow();
      native.created.clear();
      final result = await createSecret();
      expect(
        (result as Err<String, WalletProvisioningFailure>).failure,
        isA<WalletProvisioningConflictFailure>(),
      );
      final after = await singleRow();
      expect(after.id, before.id);
      expect(after.label, 'original');
      expect(after.isDefault, isFalse);
      expect(after.secretFingerprint, _fingerprint);
      expect(native.created, isEmpty);
      expect(native.deleted, isEmpty);
    });

    test('a registration conflict never compensates the winning row', () async {
      final paused = PausedCreate();
      native.onPrepare = (_) => paused.pause();
      final creating = createSecret();
      await paused.entered.future;
      final descriptors = await bitcoinDescriptors(
        secret,
        BitcoinNetwork.mainnet,
        ScriptType.bip84,
      );
      await fixture.addWallet(
        RegisteredWallet(
          id: _bip84MainnetId,
          secretFingerprint: _fingerprint,
          masterFingerprint: _fingerprint,
          signer: 'local',
          network: 'bitcoinMainnet',
          xpub: xpub,
          externalDescriptor: descriptors.external,
          internalDescriptor: descriptors.internal,
          label: 'concurrent winner',
          birthday: null,
          isDefault: true,
        ),
      );
      paused.release();
      final result = await creating;
      expect(
        (result as Err<String, WalletProvisioningFailure>).failure,
        isA<WalletProvisioningConflictFailure>(),
      );
      expect((await singleRow()).label, 'concurrent winner');
      expect(native.created, isEmpty);
      expect(native.deleted, isEmpty);
    });

    test(
      'a concurrent duplicate cannot replace a successful creation',
      () async {
        final paused = PausedCreate();
        native.onCreate = (_) => paused.pause();
        final first = createXpub();
        await paused.entered.future;
        final second = await createXpub();
        expect(
          (second as Err<void, WalletProvisioningFailure>).failure,
          isA<WalletProvisioningConflictFailure>(),
        );
        paused.release();
        expect(await first, isA<Ok<void, WalletProvisioningFailure>>());
        expect((await singleRow()).id, _bip84MainnetWatchOnlyId);
        expect(native.created, hasLength(1));
        expect(native.deleted, isEmpty);
      },
    );
  });

  group('interrupted native creation', () {
    for (final path in ['secret', 'descriptor', 'xpub']) {
      test('$path rolls back and permits retry', () async {
        native.onCreate = (key) async {
          final pending = await fixture.inventory.findWallet(key.id);
          expect(
            pending,
            isA<Ok<RegisteredWallet?, SecretFailure>>().having(
              (result) => result.value,
              'row',
              isNotNull,
            ),
            reason: 'the writer must resolve the provisional catalog row',
          );
          return const Err(SyncStorageFailure());
        };
        switch (path) {
          case 'secret':
            expect(
              await createSecret(),
              isA<Err<String, WalletProvisioningFailure>>().having(
                (result) => result.failure,
                'failure',
                isA<WalletProvisioningStorageFailure>(),
              ),
            );
          case 'descriptor':
            expect(
              await createDescriptor(),
              isA<Err<void, WalletProvisioningFailure>>().having(
                (result) => result.failure,
                'failure',
                isA<WalletProvisioningStorageFailure>(),
              ),
            );
          default:
            expect(
              await createXpub(),
              isA<Err<void, WalletProvisioningFailure>>().having(
                (result) => result.failure,
                'failure',
                isA<WalletProvisioningStorageFailure>(),
              ),
            );
        }
        expect(await rows(), isEmpty);
        expect(await loggedLines('WARNING'), [
          'Wallet creation failed catalog row removed',
        ]);
        expect(
          await loggedLines('SEVERE'),
          isEmpty,
          reason: 'a refused native write is a modeled failure, not a report',
        );
        native.onCreate = null;
        switch (path) {
          case 'secret':
            expect(
              await createSecret(),
              isA<Ok<String, WalletProvisioningFailure>>(),
            );
          case 'descriptor':
            expect(
              await createDescriptor(),
              isA<Ok<void, WalletProvisioningFailure>>(),
            );
          default:
            expect(
              await createXpub(),
              isA<Ok<void, WalletProvisioningFailure>>(),
            );
        }
        expect(
          (await singleRow()).id,
          path == 'xpub' ? _bip84MainnetWatchOnlyId : _bip84MainnetId,
        );
        expect(native.deleted, isEmpty);
      });
    }
  });

  group('resume', () {
    test('passes a clean resume and reports a failed one as storage', () async {
      var calls = 0;
      final resuming = WalletProvisioning.open(
        inventory: fixture.inventory,
        native: native,
        resume: () async {
          calls++;
          return calls == 1
              ? const Ok<void, SyncFailure>(null)
              : const Err<void, SyncFailure>(SyncStorageFailure());
        },
        properties: const [],
      );
      expect(
        await resuming.resume(),
        isA<Ok<void, WalletProvisioningFailure>>(),
      );
      expect(
        (await resuming.resume() as Err<void, WalletProvisioningFailure>)
            .failure,
        isA<WalletProvisioningStorageFailure>(),
      );
    });
  });

  group('property owners', () {
    test('prepare the registered wallet before publication', () async {
      final signers = FakePropertyStore();
      final freshness = FakePropertyStore();
      final provisioned = WalletProvisioning.open(
        inventory: fixture.inventory,
        native: native,
        resume: () async => const Ok(null),
        properties: [signers, freshness],
      );
      expect(
        await provisioned.importDescriptor(await watchOnly(secret)),
        isA<Ok<void, WalletProvisioningFailure>>(),
      );
      expect(signers.drafts, hasLength(1));
      final draft = signers.drafts.single;
      expect(draft.id, _bip84MainnetId);
      expect(draft.network, BitcoinNetwork.mainnet);
      expect(draft.secretFingerprint, isNull);
      expect(draft.signerDevice, 'Coldcard');
      expect(freshness.drafts.single.id, draft.id);
      expect((await singleRow()).id, draft.id);
    });

    test('a refusing owner prevents publication and native creation', () async {
      final refusing = FakePropertyStore()
        ..outcome = const Err(StoreSecretFailure());
      final provisioned = WalletProvisioning.open(
        inventory: fixture.inventory,
        native: native,
        resume: () async => const Ok(null),
        properties: [refusing],
      );
      expect(
        await provisioned.importDescriptor(await watchOnly(secret)),
        isA<Err<void, WalletProvisioningFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletProvisioningStorageFailure>(),
        ),
      );
      expect(refusing.drafts, hasLength(1));
      expect(await rows(), isEmpty);
      expect(native.created, isEmpty);
    });
  });

  group('imports', () {
    test('a mnemonic import registers a non-default local account', () async {
      expect(
        await accounts.importMnemonic(
          parent: secret.id,
          secrets: secrets,
          admission: admission,
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
          label: 'Imported',
        ),
        isA<Ok<void, ParentCustodyFailure>>(),
      );
      final row = await singleRow();
      expect(row.id, _bip84MainnetId);
      expect(row.isDefault, isFalse);
      expect(row.label, 'Imported');
      expect(row.signer, 'local');
      expect(row.secretFingerprint, _fingerprint);
      expect(row.birthday, isNull);
      expect(admission.runs, 1);
      expect(admission.lease.reconciled, 1);
    });

    test(
      'a descriptor import keeps its key origin and imports no seed',
      () async {
        expect(
          await createDescriptor(),
          isA<Ok<void, WalletProvisioningFailure>>(),
        );
        final row = await singleRow();
        expect(row.id, _bip84MainnetId);
        expect(row.masterFingerprint, _fingerprint);
        expect(row.secretFingerprint, isNull);
        expect(row.signer, 'remote');
        expect(row.label, 'Reviewed wallet');
        expect(row.externalDescriptor, contains("[$_fingerprint/84'/0'/0']"));
      },
    );

    test('an invalid xpub is refused before publication', () async {
      expect(
        await accounts.importXpub(
          xpub: 'xpub-not',
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
          label: '',
        ),
        isA<Err<void, WalletProvisioningFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletProvisioningInvalidFailure>(),
        ),
      );
      expect(await rows(), isEmpty);
      expect(native.prepared, isEmpty);
    });

    test('signet has no account to create', () async {
      final created = await accounts.createDefault(
        secret,
        BitcoinNetwork.signet,
      );
      expect(
        (created as Err<String, WalletProvisioningFailure>).failure,
        isA<WalletProvisioningUnsupportedFailure>(),
      );
      expect(await rows(), isEmpty);
      expect(native.prepared, isEmpty);
    });

    test('regtest refuses a legacy script after admission', () async {
      await expectLater(
        accounts.importMnemonic(
          parent: secret.id,
          secrets: secrets,
          admission: admission,
          network: BitcoinNetwork.regtest,
          scriptType: ScriptType.bip49,
          label: null,
        ),
        throwsA(
          isA<WalletProvisioningException>().having(
            (error) => error.failure,
            'failure',
            isA<WalletProvisioningUnsupportedFailure>(),
          ),
        ),
      );
      expect(await rows(), isEmpty);
      expect(native.prepared, isEmpty);
    });
  });

  group('watch-only native creation', () {
    test('a mainnet account keeps BIP32 mainnet key versions', () async {
      expect(
        await accounts.importXpub(
          xpub: 'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj',
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
          label: '',
        ),
        isA<Ok<void, WalletProvisioningFailure>>(),
      );
      final row = await singleRow();
      expect(row.xpub, startsWith('zpub'));
      expect(row.externalDescriptor, contains('xpub'));
      expect(row.internalDescriptor, contains('xpub'));
      expect(row.externalDescriptor, isNot(contains('tpub')));
      expect(native.created.single.id, row.id);
    });

    for (final interrupted in [false, true]) {
      test('the published test vpub is created through the native writer '
          'interrupted=$interrupted', () async {
        if (interrupted) {
          native.onCreate = (_) async => const Err(SyncStorageFailure());
          expect(
            await accounts.importXpub(
              xpub: _vpub,
              network: BitcoinNetwork.testnet,
              scriptType: ScriptType.bip84,
              label: '',
            ),
            isA<Err<void, WalletProvisioningFailure>>(),
          );
          expect(await rows(), isEmpty);
          native.onCreate = null;
        }
        expect(
          await accounts.importXpub(
            xpub: _vpub,
            network: BitcoinNetwork.testnet,
            scriptType: ScriptType.bip84,
            label: '',
          ),
          isA<Ok<void, WalletProvisioningFailure>>(),
        );
        final row = await singleRow();
        expect(row.network, 'bitcoinTestnet');
        expect(row.xpub, startsWith('vpub'));
        expect(row.externalDescriptor, contains('tpub'));
        expect(row.internalDescriptor, contains('tpub'));
        expect(row.isDefault, isFalse);
        expect(native.created.last.id, row.id);
      });
    }
  });
}

/// Published BIP84 test account, shared with the identity pins.
const _vpub =
    'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc';
