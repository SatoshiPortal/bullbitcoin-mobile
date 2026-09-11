import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/reconcile_payjoin_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  late SqliteDatabase database;
  late DriftWalletBackupStateRepository state;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    state = DriftWalletBackupStateRepository(database);
  });
  tearDown(() => database.close());

  test(
    'failed reads preserve the observation and allow a later retry',
    () async {
      expect(await state.get(), isA<Ok>());
      final before = await database
          .select(database.walletBackupStates)
          .getSingle();
      var failRead = true;
      final usecase = ReconcilePayjoinBackupUsecase(state, () async {
        if (failRead) throw Exception('sensitive test payload');
        return WalletPayjoinSettings(
          enabled: true,
          minimumAmountSats: 20000,
          sessionLifetimeSeconds: 3600,
        );
      });

      final failed = await usecase.execute();
      expect(failed, isA<Err<int, WalletBackupFailure>>());
      final failure = (failed as Err<int, WalletBackupFailure>).failure;
      expect(failure, isA<WalletBackupStorageFailure>());
      expect(failure.logMessage, 'Could not read Payjoin policy');
      expect(
        await database.select(database.walletBackupStates).getSingle(),
        before,
      );

      failRead = false;
      expect((await usecase.execute() as Ok).value, 1);
      expect((await usecase.execute() as Ok).value, 1);
    },
  );

  test('programming errors are not converted into storage failures', () async {
    final usecase = ReconcilePayjoinBackupUsecase(
      state,
      () async => throw StateError('programming error'),
    );
    await expectLater(usecase.execute(), throwsStateError);
    expect(await database.select(database.walletBackupStates).get(), isEmpty);
  });
}
