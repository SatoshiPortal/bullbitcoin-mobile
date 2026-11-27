import 'dart:async';
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

const _a = '01234567';
const _b = '89abcdef';
const _c = 'fedcba98';

/// A verifier whose answer per secret the test controls. Unlike a verifier that
/// always agrees, it can say "missing" or "unreadable" for a chosen secret.
final class _Proofs implements InventoryBackupVerification {
  final Map<String, BackupProof> proofs;
  final Set<String> unreadable;

  _Proofs({Map<String, BackupProof>? proofs, Set<String>? unreadable})
    : proofs = proofs ?? {},
      unreadable = unreadable ?? {};

  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async => unreadable.contains(secret.hex)
      ? const Err(BackupStateUnavailableFailure())
      : Ok(proofs[secret.hex] ?? BackupProof.missing);
}

final class _PausedProof implements InventoryBackupVerification {
  final _Proofs proofs;
  final entered = Completer<void>();
  final release = Completer<void>();

  _PausedProof(this.proofs);

  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return proofs.verify(secret);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late File file;
  late _Proofs proofs;
  late SecretsInventory inventory;
  late FakeSecureStoragePlatform storage;

  Future<SecretsInventory> open({
    InventoryBackupVerification? verifier,
  }) async => _value(
    await SecretsInventory.open(
      authority: SessionAuthority(),
      file: file,
      admission: admission,
      backupVerification: verifier,
    ),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inventory-guard-');
    storage = FakeSecureStoragePlatform()..install();
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
    proofs = _Proofs();
    inventory = await open(verifier: proofs);
  });

  tearDown(() async {
    await admission.close();
    await directory.delete(recursive: true);
  });

  Future<void> add(SecretsInventory target, String id, String seed) async =>
      _value(await target.registerWallet(_local(id, seed)));

  group('protecting a view', () {
    test('refuses an unbacked secret and changes nothing', () async {
      await add(inventory, 'wallet-a', _a);
      await add(inventory, 'wallet-b', _b);
      proofs.proofs[_a] = BackupProof.verified;

      final refusal = _failure(await inventory.setCredential('1234'));
      expect(
        refusal,
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((fingerprint) => fingerprint.hex),
          'missing',
          [_b],
        ),
      );
      expect(_value(await inventory.isProtected()), isFalse);
      expect(_value(await inventory.accessStatus()).failedAttempts, 0);
      expect(
        _value(await inventory.unbackedSecrets()).map((value) => value.hex),
        [_b],
      );

      proofs.proofs[_b] = BackupProof.verified;
      expect(_value(await inventory.unbackedSecrets()), isEmpty);
      _value(await inventory.setCredential('1234'));
      expect(_value(await inventory.isProtected()), isTrue);
    });

    test('a definite miss is reported over an unreadable secret', () async {
      await add(inventory, 'wallet-a', _a);
      await add(inventory, 'wallet-b', _b);
      proofs.unreadable.add(_a);
      expect(
        _failure(await inventory.setCredential('1234')),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((fingerprint) => fingerprint.hex),
          'missing',
          [_b],
        ),
      );

      proofs.proofs[_b] = BackupProof.verified;
      expect(
        _failure(await inventory.setCredential('1234')),
        isA<BackupStateUnavailableFailure>(),
      );
      expect(_value(await inventory.isProtected()), isFalse);
    });

    test('a view with only watch-only wallets needs no seed proof', () async {
      _value(await inventory.registerWallet(_watchOnly('watch-only')));
      expect(_value(await inventory.unbackedSecrets()), isEmpty);
      _value(await inventory.setCredential('1234'));
      expect(_value(await inventory.isProtected()), isTrue);
    });

    test('a BIP85 child depends on the proof of its parent', () async {
      await add(inventory, 'wallet-a', _a);
      _value(
        await inventory.reserveHexDerivation(
          parent: Fingerprint(_a),
          length: 16,
        ),
      );
      expect(
        _failure(await inventory.setCredential('1234')),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((fingerprint) => fingerprint.hex),
          'missing',
          [_a],
        ),
      );
      proofs.proofs[_a] = BackupProof.verified;
      _value(await inventory.setCredential('1234'));
    });

    test(
      'an inventory opened without a verifier cannot judge a seed',
      () async {
        final unbound = await open();
        await add(unbound, 'wallet-a', _a);
        expect(
          _failure(await unbound.setCredential('1234')),
          isA<BackupVerifierUnboundFailure>(),
        );
        expect(_value(await unbound.isProtected()), isFalse);
      },
    );

    test(
      'without a verifier, an unknown state reads as unknown, not unbound',
      () async {
        // Nothing owes a proof here, so binding one would decide nothing; the
        // keystore that cannot be read is the only answer, and it is unknown.
        final unbound = await open();
        await add(unbound, 'wallet-a', _a);
        _value(await unbound.removeWallet('wallet-a'));
        final secrets = Secrets(scratchDirectory: () async => directory.path);
        _value(await secrets.trash(Fingerprint(_a)));
        storage.locked = true;

        expect(
          _failure(await unbound.unbackedSecrets()),
          isA<BackupStateUnavailableFailure>(),
        );
        storage.locked = false;
      },
    );
  });

  group('a membership a removed wallet left behind', () {
    const words = [
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

    late Secrets secrets;

    setUp(() {
      secrets = Secrets(scratchDirectory: () async => directory.path);
    });

    /// Stores a real secret and registers a wallet for it, the way import
    /// publishes its membership.
    Future<Fingerprint> publish() async {
      final secret = _value(
        await secrets.import(words: words, language: Language.english),
      );
      final fingerprint = secret.info.id;
      await add(inventory, 'wallet-a', fingerprint.hex);
      return fingerprint;
    }

    /// Removes the last wallet and the seed, as deletion does: the view keeps
    /// its `secret:` membership, so this is the state that used to block a PIN.
    Future<Fingerprint> retire() async {
      final fingerprint = await publish();
      _value(await inventory.removeWallet('wallet-a'));
      _value(await secrets.trash(fingerprint));
      return fingerprint;
    }

    test('a seed left by a removed wallet no longer needs a proof', () async {
      await retire();

      expect(_value(await inventory.unbackedSecrets()), isEmpty);
      _value(await inventory.setCredential('1234'));
      expect(_value(await inventory.isProtected()), isTrue);
    });

    test('a stored seed with no wallet still needs one', () async {
      final fingerprint = await publish();
      _value(await inventory.removeWallet('wallet-a'));

      expect(
        _value(await inventory.unbackedSecrets()).map((value) => value.hex),
        [fingerprint.hex],
      );
      expect(
        _failure(await inventory.setCredential('1234')),
        isA<BackupRequiredFailure>(),
      );
      expect(_value(await inventory.isProtected()), isFalse);
    });

    test('a keystore that cannot be read is unknown, never absent', () async {
      await retire();
      storage.locked = true;

      expect(
        _failure(await inventory.unbackedSecrets()),
        isA<BackupStateUnavailableFailure>(),
      );
      expect(
        _failure(await inventory.setCredential('1234')),
        isA<BackupStateUnavailableFailure>(),
      );
      storage.locked = false;
      expect(_value(await inventory.isProtected()), isFalse);
    });

    test('an unrelated unreadable entry cannot decide a membership', () async {
      await retire();
      // One entry the plugin cannot hand back says nothing about another:
      // absence is concluded from this fingerprint's own settled read.
      storage.entries['seed_00000000'] = 'not a stored secret';

      expect(_value(await inventory.unbackedSecrets()), isEmpty);
      _value(await inventory.setCredential('1234'));
      expect(_value(await inventory.isProtected()), isTrue);
    });

    test('a new secret in a protected view still needs a proof', () async {
      // A view protected while it held only a leftover membership: adding a
      // seed now is judged on the seed, never on the membership it inherits.
      await retire();
      _value(await inventory.setCredential('1234'));
      expect(_value(await inventory.unbackedSecrets()), isEmpty);

      expect(
        _failure(await inventory.registerWallet(_local('wallet-c', _c))),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((value) => value.hex),
          'missing',
          [_c],
        ),
      );
      expect(_value(await inventory.findWallet('wallet-c')), isNull);
    });

    test('reimporting the leftover words still needs a proof', () async {
      // The view keeps the leftover's `secret:` membership, so the new seed
      // looks like an existing member. It is not: no wallet holds it, and
      // those words exist nowhere but the keystore. Importing them again must
      // prove a backup before a wallet publishes them into the view.
      final fingerprint = await retire();
      _value(await inventory.setCredential('1234'));
      final restored = _value(
        await secrets.import(words: words, language: Language.english),
      );
      expect(restored.info.id, fingerprint);

      expect(
        _failure(
          await inventory.registerWallet(_local('wallet-b', fingerprint.hex)),
        ),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((value) => value.hex),
          'missing',
          [fingerprint.hex],
        ),
      );
      expect(_value(await inventory.findWallet('wallet-b')), isNull);

      proofs.proofs[fingerprint.hex] = BackupProof.verified;
      _value(
        await inventory.registerWallet(_local('wallet-b', fingerprint.hex)),
      );
      expect(_value(await inventory.findWallet('wallet-b')), isNotNull);
    });

    test('a leftover membership is no proof for a seed it lost', () async {
      // Same shape with an empty keystore: the membership outlives the words,
      // and a wallet of a seed nobody holds is unproven either way.
      final fingerprint = await retire();
      _value(await inventory.setCredential('1234'));

      expect(
        _failure(
          await inventory.registerWallet(_local('wallet-b', fingerprint.hex)),
        ),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((value) => value.hex),
          'missing',
          [fingerprint.hex],
        ),
      );
      expect(_value(await inventory.findWallet('wallet-b')), isNull);
    });

    test('preparing properties cannot launder a leftover membership', () async {
      // Provisioning passes its callback: the proof is judged first, so the
      // properties are never prepared for a wallet that is not published.
      final fingerprint = await retire();
      _value(await inventory.setCredential('1234'));
      var prepared = false;

      final result = await inventory.registerWallet(
        _local('wallet-b', fingerprint.hex),
        prepareProperties: (_) async {
          prepared = true;
          return const Ok(null);
        },
      );

      expect(
        _failure(result),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((value) => value.hex),
          'missing',
          [fingerprint.hex],
        ),
      );
      expect(prepared, isFalse);
      expect(_value(await inventory.findWallet('wallet-b')), isNull);
    });
  });

  group('changing a PIN', () {
    Future<void> protectThenLoseProof() async {
      await add(inventory, 'wallet-a', _a);
      proofs.proofs[_a] = BackupProof.verified;
      _value(await inventory.setCredential('1234'));
      // The view predates the rule, as a migrated one does: its seed has no
      // tested backup now.
      proofs.proofs.clear();
    }

    test('without a new secret needs no proof', () async {
      await protectThenLoseProof();
      _value(await inventory.setCredential('5678'));
      await inventory.lock();
      expect(_value(await inventory.unlock('1234')).accepted, isFalse);
      expect(_value(await inventory.unlock('5678')).accepted, isTrue);
    });

    test('that fails keeps the old verifier, counter and protection', () async {
      await protectThenLoseProof();
      await inventory.lock();
      expect(_value(await inventory.unlock('0000')).accepted, isFalse);
      expect(_value(await inventory.unlock('0001')).accepted, isFalse);
      expect(_value(await inventory.unlock('1234')).accepted, isTrue);
      expect(_value(await inventory.accessStatus()).failedAttempts, 0);
      expect(_value(await inventory.unlock('0000')).accepted, isFalse);
      expect(_value(await inventory.accessStatus()).failedAttempts, 1);

      final store = _value(
        await InventoryStore.open(file, admission, existing: true),
      );
      addTearDown(store.close);
      await store.database.customStatement(
        "CREATE TRIGGER fail_rotation BEFORE UPDATE ON credentials "
        "BEGIN SELECT RAISE(ABORT, 'rotation failed'); END",
      );

      expect(await inventory.setCredential('5678'), isA<Err>());
      expect(_value(await inventory.isProtected()), isTrue);
      expect(_value(await inventory.accessStatus()).failedAttempts, 1);
      await inventory.lock();
      expect(_value(await inventory.unlock('5678')).accepted, isFalse);
      expect(_value(await inventory.unlock('1234')).accepted, isTrue);
    });
  });

  group('adding a secret to a protected view', () {
    Future<void> protect() async {
      await add(inventory, 'wallet-a', _a);
      proofs.proofs[_a] = BackupProof.verified;
      _value(await inventory.setCredential('1234'));
    }

    test('refuses a secret without a backup and publishes nothing', () async {
      await protect();
      expect(
        _failure(await inventory.registerWallet(_local('wallet-c', _c))),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((fingerprint) => fingerprint.hex),
          'missing',
          [_c],
        ),
      );
      expect(_value(await inventory.findWallet('wallet-c')), isNull);
      expect(_value(await inventory.unbackedSecrets()), isEmpty);
      expect(
        _value(await inventory.referencedFingerprints()).map((v) => v.hex),
        [_a],
      );
    });

    test('accepts a secret that has a backup', () async {
      await protect();
      proofs.proofs[_c] = BackupProof.verified;
      await add(inventory, 'wallet-c', _c);
      expect(_value(await inventory.findWallet('wallet-c')), isNotNull);
    });

    test('checks all final members when attaching a backed secret', () async {
      await protect();
      proofs.proofs.remove(_a);
      proofs.proofs[_c] = BackupProof.verified;
      expect(
        _failure(await inventory.registerWallet(_local('wallet-c', _c))),
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((value) => value.hex),
          'missing',
          [_a],
        ),
      );
      expect(_value(await inventory.findWallet('wallet-c')), isNull);
    });

    test('accepts another wallet of a seed that is already a member', () async {
      await protect();
      proofs.proofs.clear();
      await add(inventory, 'wallet-a-two', _a);
      expect(_value(await inventory.findWallet('wallet-a-two')), isNotNull);
    });

    test('accepts a watch-only wallet, which adds no seed', () async {
      await protect();
      proofs.proofs.clear();
      _value(await inventory.registerWallet(_watchOnly('watch-only')));
      expect(_value(await inventory.findWallet('watch-only')), isNotNull);
    });

    test('an unprotected view accepts a seed without a backup', () async {
      await add(inventory, 'wallet-c', _c);
      expect(_value(await inventory.findWallet('wallet-c')), isNotNull);
    });

    test('reports an existing wallet as registered, not as unbacked', () async {
      await protect();
      expect(
        _failure(await inventory.registerWallet(_local('wallet-a', _a))),
        isA<WalletAlreadyRegisteredFailure>(),
      );
    });

    test('an unreadable backup state refuses without a miss', () async {
      await protect();
      proofs.unreadable.add(_c);
      expect(
        _failure(await inventory.registerWallet(_local('wallet-c', _c))),
        isA<BackupStateUnavailableFailure>(),
      );
      expect(_value(await inventory.findWallet('wallet-c')), isNull);
    });
  });

  group('two connections', () {
    test(
      'overlapping PIN and membership writes serialize without retry',
      () async {
        await add(inventory, 'wallet-a', _a);
        proofs.proofs[_a] = BackupProof.verified;
        final paused = _PausedProof(proofs);
        final protecting = await open(verifier: paused);
        addTearDown(protecting.close);
        final pin = protecting.setCredential('1234');
        await paused.entered.future;
        var memberSettled = false;
        final member = inventory.registerWallet(_local('wallet-b', _b))
          ..then((_) => memberSettled = true);
        await Future<void>.delayed(Duration.zero);
        expect(memberSettled, isFalse);
        paused.release.complete();
        expect(await pin, isA<Ok<void, SecretFailure>>());
        expect(_failure(await member), isA<BackupRequiredFailure>());
        expect(_value(await protecting.isProtected()), isTrue);
        expect(_value(await inventory.findWallet('wallet-b')), isNull);
      },
    );
    test('a member added while the view is being protected never leaves a '
        'protected view with an unbacked secret', () async {
      await add(inventory, 'wallet-a', _a);
      proofs.proofs[_a] = BackupProof.verified;
      for (var round = 0; round < 8; round++) {
        final other = await open(verifier: proofs);
        final seed = (0x10000000 + round).toRadixString(16);
        final walletId = 'wallet-$round';
        final protectIndex = round.isOdd ? 0 : 1;
        final register = other.registerWallet(_local(walletId, seed));
        final protect = inventory.setCredential('1234');
        final List<Result<void, SecretFailure>> results;
        if (round.isOdd) {
          results = await Future.wait([protect, register]);
        } else {
          results = await Future.wait([register, protect]);
        }
        // A lock timeout between two connections fails closed; replay it
        // once the other side settled, then the guard alone decides.
        final settled = [
          for (final (index, result) in results.indexed)
            if (result case Err(failure: StoreSecretFailure()))
              await (index == protectIndex
                  ? inventory.setCredential('1234')
                  : other.registerWallet(_local(walletId, seed)))
            else
              result,
        ];
        // Exactly one side wins; the other is refused by the guard.
        expect(settled.whereType<Ok<void, SecretFailure>>(), hasLength(1));
        for (final result in settled) {
          if (result case Err(:final failure)) {
            expect(failure, isA<BackupRequiredFailure>());
          }
        }
        final protected = _value(await inventory.isProtected());
        final unbacked = _value(await inventory.unbackedSecrets());
        expect(
          protected && unbacked.isNotEmpty,
          isFalse,
          reason: 'round $round left a protected view with $unbacked',
        );
        // The next round starts from the same state, with this seed backed.
        proofs.proofs[seed] = BackupProof.verified;
        if (protected) _value(await inventory.removeCredential());
        await other.close();
      }
    });
  });
}

RegisteredWallet _local(String id, String seed) => RegisteredWallet(
  id: id,
  secretFingerprint: seed,
  masterFingerprint: seed,
  signer: 'local',
  network: 'bitcoinMainnet',
  xpub: 'xpub-marker',
  externalDescriptor: 'external-marker',
  internalDescriptor: 'internal-marker',
  label: null,
  birthday: null,
  isDefault: false,
);

RegisteredWallet _watchOnly(String id) => RegisteredWallet(
  id: id,
  secretFingerprint: null,
  masterFingerprint: '',
  signer: 'none',
  network: 'bitcoinMainnet',
  xpub: 'xpub-marker',
  externalDescriptor: 'external-marker',
  internalDescriptor: 'internal-marker',
  label: null,
  birthday: null,
  isDefault: false,
);

SecretFailure _failure<T>(Result<T, SecretFailure> result) {
  expect(result, isA<Err<T, SecretFailure>>());
  return (result as Err<T, SecretFailure>).failure;
}

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
