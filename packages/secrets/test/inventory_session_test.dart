import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late File file;
  late SecretsInventory inventory;
  late BackgroundWalletDescriptors background;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inventory-session-');
    FakeSecureStoragePlatform().install();
    file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final result = await participant.prepare(exclusive, OwnerOrigin.fresh);
      final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    inventory = _value(
      await SecretsInventory.open(file: file, admission: admission),
    );
    background = _value(
      await BackgroundWalletDescriptors.open(file: file, admission: admission),
    );
  });

  tearDown(() async {
    await admission.close();
    await directory.delete(recursive: true);
  });

  test(
    'publishes catalog and membership only after properties are ready',
    () async {
      const id = 'wpkh([01234567/84h/1h/0h]):regtest';
      final wallet = _registration(
        id,
        network: 'bitcoinRegtest',
        signer: 'local',
      );
      final attempt = await inventory.registerWallet(
        wallet,
        prepareProperties: () async => const Err(StoreSecretFailure()),
      );
      expect(attempt, isA<Err<void, SecretFailure>>());
      expect(_value(await inventory.findWallet(id)), isNull);
      expect(_value(await background.list()), isEmpty);

      var preparations = 0;
      final results = await Future.wait([
        for (var attempt = 0; attempt < 2; attempt++)
          inventory.registerWallet(
            wallet,
            prepareProperties: () async {
              preparations++;
              return const Ok(null);
            },
          ),
      ]);
      expect(preparations, 1);
      expect(results.whereType<Ok<void, SecretFailure>>(), hasLength(1));
      expect(
        results.whereType<Err<void, SecretFailure>>().single.failure,
        isA<WalletAlreadyRegisteredFailure>(),
      );
      expect(_value(await background.list()).single.id, id);
    },
  );

  test('targeted lookup keeps testnet and regtest distinct', () async {
    const testId = 'wpkh([01234567/84h/1h/0h])';
    const regtestId = '$testId:regtest';
    _value(
      await inventory.registerWallet(
        _registration(testId, network: 'bitcoinTestnet', signer: 'remote'),
      ),
    );
    _value(
      await inventory.registerWallet(
        _registration(regtestId, network: 'bitcoinRegtest', signer: 'local'),
      ),
    );

    final WalletInventory readOnly = inventory;
    final testnet = _value(await readOnly.readWallet(testId));
    expect(testnet.network, BitcoinNetwork.testnet);
    expect(testnet.signer, WalletSigner.remote);
    expect(testnet.masterFingerprint, Fingerprint('01234567'));
    expect(testnet.secretFingerprint, isNull);
    expect(testnet.derivationPath, "m/84'/1'/7'");
    expect(testnet.scriptType, ScriptType.bip84);

    final regtest = _value(await inventory.readWallet(regtestId));
    expect(regtest.id, regtestId);
    expect(regtest.network, BitcoinNetwork.regtest);
    expect(regtest.secretFingerprint, Fingerprint('01234567'));
  });

  test(
    'recovery evidence comes only from authorized local Bitcoin wallets',
    () async {
      const localId = 'wpkh([01234567/84h/1h/0h]):regtest';
      final local = _registration(
        localId,
        network: 'bitcoinRegtest',
        signer: 'local',
        isDefault: true,
      );
      _value(await inventory.registerWallet(local));
      _value(
        await inventory.registerWallet(
          _registration(
            'wpkh([01234567/84h/1h/0h])',
            network: 'bitcoinTestnet',
            signer: 'remote',
          ),
        ),
      );
      final evidence = _value(await inventory.recoveryWallets()).single;
      expect(evidence.id, localId);
      expect(evidence.network, BitcoinNetwork.regtest);
      expect(evidence.fingerprint, Fingerprint('01234567'));
      expect(evidence.isDefault, isTrue);
      expect(evidence.descriptors, (
        external: local.externalDescriptor,
        internal: local.internalDescriptor,
      ));

      final pending = inventory.recoveryWallets();
      inventory.lock();
      expect(
        await pending,
        isA<Err<List<BitcoinRecoveryWallet>, SecretFailure>>(),
      );
      expect(
        await inventory.recoveryWallets(),
        isA<Err<List<BitcoinRecoveryWallet>, SecretFailure>>(),
      );
    },
  );

  test('distinguishes absent, unreadable and failed storage reads', () async {
    const id = 'wpkh([01234567/84h/1h/0h])';
    final storage = _value(
      await InventoryStore.open(file, admission, existing: true),
    );
    addTearDown(storage.close);
    _value(
      await inventory.registerWallet(
        _registration(id, network: 'bitcoinTestnet', internal: 'malformed'),
      ),
    );
    expect(
      await inventory.readWallet(id),
      isA<Err<WalletRegistration, SecretFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<UnreadableWalletFailure>(),
      ),
    );
    expect(
      await inventory.walletsForNetwork(BitcoinNetwork.testnet),
      isA<Err<WalletSelection, SecretFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<UnreadableWalletFailure>(),
      ),
    );
    await storage.database.customStatement('DELETE FROM view_members');
    expect(
      await inventory.readWallet(id),
      isA<Err<WalletRegistration, SecretFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletRegistrationNotFoundFailure>(),
      ),
    );
    expect(
      _value(await inventory.walletsForNetwork(BitcoinNetwork.testnet)).wallets,
      isEmpty,
    );
    await storage.database.customStatement('DROP TABLE wallets');
    expect(
      await inventory.readWallet(id),
      isA<Err<WalletRegistration, SecretFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<FetchSecretFailure>(),
      ),
    );
  });

  test(
    'selection is exact, stable, and preserves conflicting defaults',
    () async {
      const first = 'wpkh([01234567/84h/1h/0h])';
      const second = 'wpkh([89abcdef/84h/1h/0h])';
      const malformed = 'wpkh([01234567/84h/1h/1h])';
      const other = '$first:regtest';
      for (final (id, network, internal) in [
        (second, 'bitcoinTestnet', null),
        (other, 'bitcoinRegtest', null),
        (first, 'bitcoinTestnet', null),
        (malformed, 'bitcoinTestnet', 'malformed'),
      ]) {
        _value(
          await inventory.registerWallet(
            _registration(
              id,
              network: network,
              internal: internal,
              isDefault: true,
            ),
          ),
        );
      }
      final testnet = _value(
        await inventory.walletsForNetwork(BitcoinNetwork.testnet),
      );
      expect(testnet.wallets.map((wallet) => wallet.id), [first, second]);
      expect(testnet.isComplete, isFalse);
      expect(testnet.wallets.first.secretFingerprint, isNull);
      expect(testnet.wallets.first.label, '');
      expect(testnet.wallets.first.birthday, DateTime.utc(2026, 11, 21));
      expect(testnet.defaults, testnet.wallets);
      expect(testnet.defaultWallet, isNull);
      expect(testnet.wallets.clear, throwsUnsupportedError);
      expect(testnet.defaults.clear, throwsUnsupportedError);

      final regtest = _value(
        await inventory.walletsForNetwork(BitcoinNetwork.regtest),
      );
      expect(regtest.defaultWallet?.id, other);
      expect(regtest.isComplete, isTrue);
      final liquid = _value(
        await inventory.walletsForNetwork(LiquidNetwork.testnet),
      );
      expect(liquid.wallets, isEmpty);
      expect(liquid.isComplete, isTrue);
      expect(liquid.defaultWallet, isNull);
      expect(
        await inventory.walletsForNetwork(BitcoinNetwork.signet),
        isA<Err<WalletSelection, SecretFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<UnsupportedNetworkFailure>(),
        ),
      );
    },
  );

  test(
    'locking revokes pending targeted and network inventory reads',
    () async {
      const id = 'wpkh([01234567/84h/1h/0h])';
      _value(
        await inventory.registerWallet(
          _registration(id, network: 'bitcoinTestnet'),
        ),
      );
      final targeted = inventory.readWallet(id);
      final choices = inventory.walletsForNetwork(BitcoinNetwork.testnet);
      inventory.lock();

      expect(
        await targeted,
        isA<Err<WalletRegistration, SecretFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<UseSecretFailure>(),
        ),
      );
      expect(
        await choices,
        isA<Err<WalletSelection, SecretFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<UseSecretFailure>(),
        ),
      );
    },
  );

  test(
    'locking withdraws foreground inventory and keeps background grant',
    () async {
      expect(
        await inventory.registerWallet(_wallet('test-wallet', '01234567')),
        isA<Ok>(),
      );
      final pending = inventory.listWallets();
      inventory.lock();

      expect(await pending, isA<Err>());
      expect(await inventory.listWallets(), isA<Err>());
      expect(await inventory.findWallet('test-wallet'), isA<Err>());
      expect(_value(await background.list()).single.id, 'test-wallet');
      expect(await inventory.resumeUnprotected(), isA<Ok>());
      expect(_value(await inventory.listWallets()).single.id, 'test-wallet');
    },
  );

  test('background opt-out stops descriptor access at the owner', () async {
    expect(
      await inventory.registerWallet(_wallet('test-wallet', '01234567')),
      isA<Ok>(),
    );
    expect(_value(await background.list()), hasLength(1));
    expect(await inventory.setBackgroundEnabled(false), isA<Ok>());
    inventory.lock();
    expect(_value(await background.list()), isEmpty);
    expect(await inventory.setBackgroundEnabled(true), isA<Err>());
  });

  test(
    'reopening with an expired wall deadline still delays PIN comparison',
    () async {
      final pin = DateTime.now().microsecondsSinceEpoch.toString();
      _value(
        await inventory.setCredential(
          pin,
          backupVerification: _VerifiedBackup(allowEmpty: true),
        ),
      );
      await inventory.close();
      final store = _value(
        await InventoryStore.open(file, admission, existing: true),
      );
      await store.database.customStatement(
        'UPDATE access_state SET failed_attempts = ?, locked_until = ?',
        [
          5,
          DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        ],
      );
      await store.close();

      final reopened = _value(
        await SecretsInventory.open(file: file, admission: admission),
      );
      final status = _value(await reopened.accessStatus());
      expect(status.remaining.inSeconds, inInclusiveRange(59, 60));
      final attempt = _value(await reopened.unlock(pin));
      expect(attempt.accepted, isFalse);
      expect(attempt.failedAttempts, 5);
    },
  );

  test(
    'the verified default wallet is sufficient to set and change a PIN',
    () async {
      final backup = _VerifiedBackup();
      expect(_value(await inventory.hasVerifiedBackups(backup)), isFalse);
      _value(
        await inventory.registerWallet(
          _registration(
            'wpkh([01234567/84h/1h/0h])',
            network: 'bitcoinTestnet',
            signer: 'local',
            isDefault: true,
          ),
        ),
      );
      _value(await inventory.registerWallet(_wallet('unverified', '89abcdef')));
      final pin = DateTime.now().microsecondsSinceEpoch.toString();

      expect(_value(await inventory.hasVerifiedBackups(backup)), isTrue);
      _value(await inventory.setCredential(pin, backupVerification: backup));
      final replacement = '${pin}0';
      _value(
        await inventory.setCredential(replacement, backupVerification: backup),
      );
      inventory.lock();
      expect(_value(await inventory.unlock(replacement)).accepted, isTrue);
    },
  );

  test(
    'reservations are serial per parent and include revoked records',
    () async {
      final parent = Fingerprint('01234567');
      final otherParent = Fingerprint('89abcdef');
      expect(
        await inventory.registerWallet(_wallet('one', parent.hex)),
        isA<Ok>(),
      );
      expect(
        await inventory.registerWallet(_wallet('two', otherParent.hex)),
        isA<Ok>(),
      );
      Future<RecordedDerivation> reserve(Fingerprint parent) async => _value(
        await inventory.reserveHexDerivation(parent: parent, length: 16),
      );

      final pair = await Future.wait([reserve(parent), reserve(parent)]);
      expect(pair.map((record) => record.index), unorderedEquals([0, 1]));
      expect(
        await inventory.setDerivationActive(pair.last, active: false),
        isA<Ok>(),
      );
      expect((await reserve(parent)).index, 2);
      expect((await reserve(otherParent)).index, 0);
    },
  );

  test('ordinary module key handles cannot open the inventory', () {
    final keys = Secrets(scratchDirectory: () async => directory.path);
    expect(() => keys.databaseKeys(module: 'secrets'), throwsArgumentError);
  });
}

final class _VerifiedBackup implements InventoryBackupVerification {
  final bool allowEmpty;

  _VerifiedBackup({this.allowEmpty = false});

  @override
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    List<WalletRegistration> defaults,
  ) async => Ok(
    defaults.isEmpty
        ? allowEmpty
        : defaults.single.secretFingerprint?.hex == '01234567',
  );
}

RegisteredWallet _wallet(String id, String parent) => RegisteredWallet(
  id: id,
  secretFingerprint: parent,
  masterFingerprint: parent,
  signer: 'local',
  network: 'bitcoinMainnet',
  xpub: 'xpub-marker',
  externalDescriptor: 'external-marker',
  internalDescriptor: 'internal-marker',
  label: null,
  birthday: null,
  isDefault: false,
);

RegisteredWallet _registration(
  String id, {
  required String network,
  String signer = 'none',
  String? internal,
  bool isDefault = false,
}) => RegisteredWallet(
  id: id,
  secretFingerprint: signer == 'local' ? '01234567' : null,
  masterFingerprint: signer == 'none' ? '' : '01234567',
  signer: signer,
  network: network,
  xpub: 'public-key-marker',
  externalDescriptor: "wpkh([01234567/84'/1'/7']public-key-marker/0/*)",
  internalDescriptor: internal ?? 'wpkh(public-key-marker/1/*)',
  label: '',
  birthday: '2026-11-21T00:00:00Z',
  isDefault: isDefault,
);

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
