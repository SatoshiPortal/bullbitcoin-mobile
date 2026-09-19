import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_publication.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_snapshot_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/wallet_backup_locator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _Vaults extends Mock implements BullVaultFacade {}

class _Snapshots extends Fake implements WalletBackupSnapshotRepository {}

void main() {
  late GetIt services;
  late SqliteDatabase database;
  late _Identity identity;
  setUp(() {
    services = GetIt.asNewInstance();
    database = SqliteDatabase(NativeDatabase.memory());
    identity = _Identity();
    services.registerSingleton<SqliteDatabase>(database);
    services.registerSingleton<NostrIdentityFacade>(identity);
    services.registerSingleton<BullVaultFacade>(_Vaults());
    WalletBackupLocator.setup(services);
  });
  tearDown(() async {
    await services.reset();
    await database.close();
  });
  test(
    'opening control keeps the undecided choice without a credential lookup',
    () async {
      final facade = services<WalletBackupFacade>();
      final result = await facade.getControl();
      final control =
          (result as Ok<WalletBackupControl, WalletBackupFailure>).value;
      expect(control.enabled, isNull);
      expect(control.recoveryIncomplete, isFalse);
      verifyZeroInteractions(identity);
    },
  );
  test(
    'off survives subsequent reads and publication never reads identity or inventory',
    () async {
      await services.unregister<WalletBackupSnapshotRepository>();
      services.registerSingleton<WalletBackupSnapshotRepository>(_Snapshots());
      expect(
        await services<SetWalletBackupEnabledUsecase>().execute(false),
        isA<Ok>(),
      );
      final publication = await services<PublishWalletBackupUsecase>()
          .execute();
      expect(
        (publication as Ok<WalletBackupPublication, WalletBackupFailure>).value,
        WalletBackupPublication.inactive,
      );
      final control = await services<WalletBackupFacade>().getControl();
      expect(
        (control as Ok<WalletBackupControl, WalletBackupFailure>).value.enabled,
        isFalse,
      );
      verifyZeroInteractions(identity);
    },
  );
  test(
    'an explicit words check uses the supplied credential path and invalid input makes no request',
    () async {
      when(
        () => identity.fromWords('invalid'),
      ).thenReturn(const Err(InvalidDataRecoveryWords()));
      final result = await services<WalletBackupFacade>().inspect(
        words: 'invalid',
      );
      expect(result, isA<Err<WalletBackupInspection, WalletBackupFailure>>());
      verify(() => identity.fromWords('invalid')).called(1);
      verifyNever(identity.resolve);
    },
  );
}
