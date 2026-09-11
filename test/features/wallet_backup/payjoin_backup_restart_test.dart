import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/reconcile_payjoin_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_job_runner.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_triggers.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Wallet extends Mock implements PayjoinWalletPort {}

class _Blockchain extends Mock implements PayjoinBlockchainPort {}

class _Fees extends Mock implements PayjoinFeesPort {}

class _Transactions extends Mock implements PayjoinTransactionPort {}

class _Labels extends Mock implements PayjoinLabelsPort {}

class _Legacy extends Mock implements PayjoinLegacyDataPort {}

class _Log extends Mock implements PayjoinLogPort {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (changed, failFirstObservation) in [
    (false, false),
    (true, false),
    (true, true),
  ]) {
    test(
      'restart and resume reconcile Payjoin (changed: $changed, failure: $failFirstObservation)',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'bbm-payjoin-backup-',
        );
        final database = SqliteDatabase(NativeDatabase.memory());
        final state = DriftWalletBackupStateRepository(database);
        final legacy = _Legacy();
        when(legacy.readSnapshot).thenAnswer(
          (_) async => const PayjoinLegacySnapshot(
            sourceSchemaVersion: 17,
            senders: [],
            receivers: [],
          ),
        );
        Future<PayjoinLifecycle> open() async =>
            (await openPayjoin(
                      databasePath: '${directory.path}/payjoin.sqlite',
                      wallet: _Wallet(),
                      blockchain: _Blockchain(),
                      fees: _Fees(),
                      transactions: _Transactions(),
                      labels: _Labels(),
                      legacyData: legacy,
                      log: _Log(),
                    )
                    as Ok<PayjoinLifecycle, PayjoinFailure>)
                .value;

        var lifecycle = await open();
        addTearDown(() async {
          await lifecycle.dispose();
          await database.close();
          await directory.delete(recursive: true);
        });
        expect(await state.setEnabled(true), isA<Ok>());
        expect(
          await state.recordObservedPayjoinPolicy(
            _backupPolicy(
              (await lifecycle.payjoin.policy.load()
                      as Ok<PayjoinPolicy, PayjoinFailure>)
                  .value,
            ),
          ),
          isA<Ok>(),
        );
        expect(
          await state.recordPublication(
            publishedRevision: 2,
            succeededAt: 1,
            checkpoint: WalletBackupRemoteCheckpoint(
              generation: 1,
              etag: 'a' * 64,
              ciphertextSha256: 'b' * 64,
            ),
          ),
          isA<Ok>(),
        );
        expect((await state.get() as Ok).value.dirty, false);

        if (changed) {
          expect(
            await lifecycle.payjoin.policy.setMinimumAmount(
              Sats.fromInt(20000),
            ),
            isA<Ok>(),
          );
        }
        await lifecycle.dispose();
        lifecycle = await open();
        final policy = lifecycle.payjoin.policy;
        expect(
          (await policy.load() as Ok).value.minimumAmount,
          Sats.fromInt(changed ? 20000 : 10000),
        );

        final firstPublish = Completer<void>();
        final initialPolicy = Completer<void>();
        final observation = Completer<void>();
        final resumedObservation = Completer<void>();
        if (failFirstObservation) {
          await database.customStatement('''
            CREATE TRIGGER reject_initial_payjoin_observation
            BEFORE UPDATE OF local_revision ON wallet_backup_states
            BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
          ''');
        }
        final runner = WalletBackupJobRunner(
          publish: () async {
            if (!firstPublish.isCompleted) firstPublish.complete();
            return const Ok(null);
          },
        );
        final reconcile = ReconcilePayjoinBackupUsecase(state, () async {
          final current =
              (await policy.load() as Ok<PayjoinPolicy, PayjoinFailure>).value;
          return _backupPolicy(current);
        });
        final triggers = WalletBackupTriggers(
          recordedChanges: const Stream.empty(),
          unrecordedChanges: policy.watch().map((_) {
            if (!initialPolicy.isCompleted) initialPolicy.complete();
          }),
          syncResults: const Stream.empty(),
          runner: runner,
          recordMutation: () async {
            final result = await reconcile.execute();
            if (!observation.isCompleted) {
              observation.complete();
            } else if (!resumedObservation.isCompleted) {
              resumedObservation.complete();
            }
            return result;
          },
        );
        addTearDown(() async {
          await triggers.dispose().timeout(const Duration(seconds: 5));
          await runner.dispose();
        });
        triggers.start();
        await Future.wait([
          firstPublish.future,
          initialPolicy.future,
          observation.future,
        ]).timeout(const Duration(seconds: 5));
        expect(
          (await state.get() as Ok).value.dirty,
          changed && !failFirstObservation,
          reason:
              'the package policy changed while no backup listener was running',
        );
        if (failFirstObservation) {
          await database.customStatement(
            'DROP TRIGGER reject_initial_payjoin_observation',
          );
        }
        triggers.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await resumedObservation.future.timeout(const Duration(seconds: 5));
        final resumed = (await state.get() as Ok).value;
        expect(resumed.dirty, changed);
        expect(
          resumed.localRevision,
          changed ? 3 : 2,
          reason:
              'retry a failed observation without dirtying unchanged settings',
        );
      },
    );
  }
}

WalletPayjoinSettings _backupPolicy(PayjoinPolicy policy) =>
    WalletPayjoinSettings(
      enabled: policy.enabled,
      minimumAmountSats: policy.minimumAmount.value.toInt(),
      sessionLifetimeSeconds: policy.sessionLifetime.inSeconds,
    );
