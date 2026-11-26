import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

/// Locking closes the admission first, then lets admitted work settle. A write
/// that reaches its commit after the lock is rolled back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late SecretsInventory inventory;
  late SessionAuthority authority;
  late _BlockingStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('inventory-lock-');
    storage = _BlockingStorage()..install();
    final file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final prepared = await SecretsImport(file: file)
          .prepare(exclusive, OwnerOrigin.fresh);
      final owner = (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    authority = SessionAuthority();
    inventory = _value(
      await SecretsInventory.open(
        file: file,
        admission: admission,
        authority: authority,
      ),
    );
  });

  tearDown(() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  RegisteredWallet wallet() => const RegisteredWallet(
    id: 'wpkh([01234567/84h/1h/0h])',
    secretFingerprint: null,
    masterFingerprint: '',
    signer: 'none',
    network: 'bitcoinTestnet',
    xpub: 'public-key-marker',
    externalDescriptor: "wpkh([01234567/84'/1'/7']public-key-marker/0/*)",
    internalDescriptor: 'wpkh(public-key-marker/1/*)',
    label: '',
    birthday: null,
    isDefault: false,
  );

  test(
    'a write that reaches its commit after the lock is rolled back',
    () async {
      final preparing = Completer<void>();
      final release = Completer<void>();
      final registering = inventory.registerWallet(
        wallet(),
        prepareProperties: (_) async {
          preparing.complete();
          await release.future;
          return const Ok(null);
        },
      );
      await preparing.future;

      final locking = inventory.lock();
      release.complete();
      final registered = await registering;
      expect(await locking, isTrue);

      expect(registered, isA<Err<void, SecretFailure>>());
      _value(await inventory.resumeUnprotected());
      expect(
        _value(await inventory.findWallet(wallet().id)),
        isNull,
        reason: 'nothing of the interrupted write may be left behind',
      );
    },
  );

  test(
    'lock closes at once and stays closed when drainage times out',
    () async {
      final preparing = Completer<void>();
      final release = Completer<void>();
      final registering = inventory.registerWallet(
        wallet(),
        prepareProperties: (_) async {
          preparing.complete();
          await release.future;
          return const Ok(null);
        },
      );
      await preparing.future;

      final drained = await inventory.lock(
        drain: const Duration(milliseconds: 50),
      );

      expect(drained, isFalse);
      expect(inventory.isLocked, isTrue);
      expect(
        await inventory.listWallets(),
        isA<Err<List<RegisteredWallet>, SecretFailure>>(),
        reason: 'a timeout never reopens the lock',
      );
      final resuming = inventory.resumeUnprotected();
      final premature = await resuming.timeout(
        const Duration(milliseconds: 250),
        onTimeout: () => const Err(UseSecretFailure('resume did not settle')),
      );
      expect(
        await inventory.unlock('1234'),
        isA<Err<AccessAttempt, SecretFailure>>(),
      );
      release.complete();
      expect(await registering, isA<Err<void, SecretFailure>>());
      await resuming;
      expect(premature, isA<Err<void, SecretFailure>>());
      expect(inventory.isLocked, isTrue);
    },
  );

  test('work committed before the lock reports its true result', () async {
    final registered = await inventory.registerWallet(wallet());
    expect(registered, isA<Ok<void, SecretFailure>>());
    expect(await inventory.lock(), isTrue);
    _value(await inventory.resumeUnprotected());
    expect(_value(await inventory.findWallet(wallet().id)), isNotNull);
  });

  test(
    'BIP85 does not reserve or reveal after revocation during seed lookup',
    () async {
      final secrets = Secrets(
        authority: authority,
        scratchDirectory: () async => directory.path,
      );
      final secret = _value(await secrets.generate());
      final fingerprint = secret.id;
      _value(
        await inventory.registerWallet(
          RegisteredWallet(
            id: 'bip85-parent',
            secretFingerprint: fingerprint.hex,
            masterFingerprint: fingerprint.hex,
            signer: 'local',
            network: 'bitcoinTestnet',
            xpub: 'public-key-marker',
            externalDescriptor: 'external-marker',
            internalDescriptor: 'internal-marker',
            label: null,
            birthday: null,
            isDefault: false,
          ),
        ),
      );
      storage.block = true;
      final deriving = inventory
          .bip85(secrets)
          .deriveNextHex(parent: fingerprint, length: 16);
      await storage.entered.future.timeout(const Duration(seconds: 5));
      final locking = inventory.lock();
      storage.release.complete();
      expect(await deriving, isA<Err>());
      expect(await locking, isTrue);
      _value(await inventory.resumeUnprotected());
      expect(_value(await inventory.listDerivations()), isEmpty);
    },
  );

  test('unprotected reopening cannot supersede a later lock', () async {
    final first = inventory.lock();
    expect(inventory.isLocked, isTrue);
    final second = inventory.lock();

    await first;
    expect(await second, isTrue);
    expect(inventory.isLocked, isTrue);
  });

  test(
    'a lock invoked by a synchronous listener supersedes reopening',
    () async {
      Future<bool>? later;
      final subscription = inventory.lockedChanges.listen((locked) {
        if (locked) later = inventory.lock();
      });
      final first = inventory.lock();

      expect(await first, isTrue);
      final second = later;
      expect(second, isNotNull);
      if (second != null) expect(await second, isTrue);
      expect(inventory.isLocked, isTrue);
      await subscription.cancel();
    },
  );

  test(
    'an unprotected view reopens explicitly after the lock has drained',
    () async {
      final locking = inventory.lock();
      expect(inventory.isLocked, isTrue);
      expect(await locking, isTrue);
      expect(inventory.isLocked, isTrue);
      _value(await inventory.resumeUnprotected());
      expect(inventory.isLocked, isFalse);
    },
  );
}

class _BlockingStorage extends FakeSecureStoragePlatform {
  bool block = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (block) {
      block = false;
      entered.complete();
      await release.future;
    }
    return super.read(key: key, options: options);
  }
}

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
