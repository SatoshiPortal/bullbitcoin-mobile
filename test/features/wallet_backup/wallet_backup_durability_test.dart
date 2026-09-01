import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide ScriptType;

import 'support/wallet_backup_behavior_harness.dart';

/// What survives a crash, a queue, and a rate limit.
///
/// Everything Bull backup still owes the server lives in two durable numbers
/// and one durable fence, so these tests assert against restarts and injected
/// faults rather than against in-memory bookkeeping.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a change during a publication leaves one more pass to run', () async {
    final device = await _device();
    expect(await device.facade.setEnabled(true), _succeeds);
    device.startCoordinator();
    final storesAfterEnabling = device.remote.storeCount;

    // A wallet is recorded while the first store is still in flight. Its
    // revision lands in the same transaction as the manifest write, so the
    // publication that is already running cannot acknowledge it.
    var interrupted = false;
    device.remote.beforeStore = () async {
      if (interrupted) return;
      interrupted = true;
      await _addWallet(device, walletId: 'mid-flight', label: 'Mid flight');
      expect((await device.readState()).dirty, isTrue);
    };

    expect(await device.facade.backupNow(), _succeeds);

    await settleUntil(
      () async => !(await device.readState()).dirty,
      description: 'the follow-up publication',
    );
    expect(device.remote.storeCount, storesAfterEnabling + 2);

    // Nothing else is owed, so no further pass runs.
    await device.runner.settle();
    await pumpEventQueue();
    expect(device.remote.storeCount, storesAfterEnabling + 2);
  });

  test(
    'deletion cannot race an older store, and no store follows it',
    () async {
      final device = await _device();
      expect(await device.facade.setEnabled(true), _succeeds);
      await _addWallet(device, walletId: 'doomed', label: 'Doomed');

      final storeReached = Completer<void>();
      final releaseStore = Completer<void>();
      device.remote.beforeStore = () async {
        if (!storeReached.isCompleted) storeReached.complete();
        await releaseStore.future;
      };

      final publishing = device.facade.backupNow();
      await storeReached.future;

      // Both queue behind the store that is already running.
      final disabling = device.facade.setEnabled(false);
      final deleting = device.facade.deleteRemoteBackup(confirmed: true);
      await pumpEventQueue();
      expect(device.remote.isEmpty, isFalse, reason: 'the delete must wait');

      releaseStore.complete();
      expect(await publishing, _succeeds);
      expect(await disabling, _succeeds);
      expect(await deleting, _succeeds);

      expect(device.remote.isEmpty, isTrue);
      final storesAfterDelete = device.remote.storeCount;

      // A change arriving after the delete cannot recreate the object, because
      // deletion required automatic backup to be off first (decision 9).
      device.startCoordinator();
      await _addWallet(device, walletId: 'after-delete', label: 'After');
      await device.runner.settle();
      await pumpEventQueue();

      expect(device.remote.isEmpty, isTrue);
      expect(device.remote.storeCount, storesAfterDelete);
    },
  );

  test(
    'deleting a remote backup requires automatic backup to be off',
    () async {
      final device = await _device();
      expect(await device.facade.setEnabled(true), _succeeds);

      expect(
        await device.facade.deleteRemoteBackup(confirmed: true),
        isA<Err<void, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupDeleteRequiresDisabledFailure>(),
        ),
      );
      expect(device.remote.isEmpty, isFalse);
    },
  );

  test('an apply that dies part-way refuses publication until it is '
      'redone', () async {
    final server = FakeWalletBackupRemote();
    final device = await _device(remote: server);
    expect(await device.facade.setEnabled(true), _succeeds);

    final elsewhere = await _device(remote: server);
    await _addWallet(elsewhere, walletId: 'elsewhere', label: 'Elsewhere');
    expect(await elsewhere.facade.setEnabled(true), _succeeds);
    final published = server.storedCiphertext;

    device.metadata.recoverError = StateError('process died mid-apply');
    await expectLater(device.facade.recover(), throwsStateError);

    // The fence is durable, and applying reads as blocked precisely because a
    // run that never finished cannot be told apart from one still going.
    var state = await device.readState();
    expect(state.recoveryState, WalletBackupRecoveryState.applying);
    expect(state.recoveryBlocked, isTrue);
    expect(state.canPublish, isFalse);

    await _addWallet(device, walletId: 'local', label: 'Local');
    expect(
      await device.facade.backupNow(),
      isA<Err<void, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupRecoveryBlockedFailure>(),
      ),
    );
    expect(server.storedCiphertext, published);

    device.metadata.recoverError = null;
    expect(
      (await device.facade.recover()).status,
      WalletBackupRecoveryStatus.restored,
    );

    state = await device.readState();
    expect(state.recoveryState, WalletBackupRecoveryState.idle);
    expect(state.dirty, isTrue, reason: 'local work survives the fence');
    expect(await device.facade.backupNow(), _succeeds);
  });

  test('a rate-limited store stops every remote call until the gate '
      'lifts', () async {
    var now = DateTime.utc(2026);
    final device = await _device(now: () => now);
    expect(await device.facade.setEnabled(true), _succeeds);
    await _addWallet(device, walletId: 'limited', label: 'Limited');

    device.remote.storeFailure = const WalletBackupRateLimitedFailure(
      Duration(seconds: 30),
    );
    expect(
      await device.facade.backupNow(),
      isA<Err<void, WalletBackupFailure>>(),
    );

    device.remote.storeFailure = null;
    final attemptsWhileLimited = device.remote.storeAttempts;
    final fetchesWhileLimited = device.remote.fetchCount;

    expect(
      await device.facade.backupNow(),
      isA<Err<void, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupRateLimitedFailure>(),
      ),
    );
    expect(device.remote.storeAttempts, attemptsWhileLimited);
    expect(device.remote.fetchCount, fetchesWhileLimited);
    expect((await device.readState()).dirty, isTrue);

    now = now.add(const Duration(seconds: 30));

    expect(await device.facade.backupNow(), _succeeds);
    expect(device.remote.storeAttempts, attemptsWhileLimited + 1);
    expect((await device.readState()).dirty, isFalse);
  });

  test('a restarted app still owes the publication it never made', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final server = FakeWalletBackupRemote();

    final before = await WalletBackupBehaviorHarness.create(
      remote: server,
      database: database,
    );
    expect(await before.facade.setEnabled(true), _succeeds);
    final publishedAtEnabling = server.storedCiphertext;
    // No triggers are running, so this change is recorded and never sent.
    await _addWallet(before, walletId: 'unsent', label: 'Unsent');
    final pending = await before.readState();
    expect(pending.dirty, isTrue);
    expect(pending.localRevision, greaterThan(pending.uploadedRevision));
    await before.dispose(closeDatabase: false);

    final after = await WalletBackupBehaviorHarness.create(
      remote: server,
      database: database,
    );
    addTearDown(() => after.dispose(closeDatabase: false));

    final resumed = await after.readState();
    expect(resumed.dirty, isTrue, reason: 'revisions outlive the process');
    expect(resumed.canPublish, isTrue);
    expect(server.storedCiphertext, publishedAtEnabling);

    after.startCoordinator();
    await settleUntil(
      () async => !(await after.readState()).dirty,
      description: 'the publication the restart inherited',
    );
    expect(server.storedCiphertext, isNot(publishedAtEnabling));
  });
}

final Matcher _succeeds = isA<Ok<void, WalletBackupFailure>>();

Future<WalletBackupBehaviorHarness> _device({
  FakeWalletBackupRemote? remote,
  DateTime Function()? now,
}) async {
  final harness = await WalletBackupBehaviorHarness.create(
    remote: remote,
    now: now,
  );
  addTearDown(harness.dispose);
  return harness;
}

Future<void> _addWallet(
  WalletBackupBehaviorHarness device, {
  required String walletId,
  required String label,
}) async {
  final result = await device.keychainManifest.recordWallet(
    parentFingerprint: device.fingerprint,
    wallet: KeychainManifestWalletInventoryBinding(
      walletId: walletId,
      seedFingerprint: Fingerprint(
        walletId.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0'),
      ),
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      provenance: WalletProvenance.importedMnemonic,
      derivationPath: "m/84'/0'/0'",
      seedPassphraseUsed: false,
      label: label,
    ),
  );
  expect(result, isA<Ok<bool, KeychainManifestFailure>>());
}
