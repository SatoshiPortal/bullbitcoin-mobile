import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
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

class _Catalog extends Mock implements KeychainManifestFacade {}

class _NativeVaults extends Fake implements BullVaultBackupRepository {}

class _Wallets extends Fake implements WalletInventoryBackupRepository {}

class _Metadata extends Fake implements WalletMetadataBackupRepository {}

class _Files extends Fake implements WalletBackupFileRepository {}

void main() {
  late GetIt services;
  late SqliteDatabase database;
  late _Identity identity;
  setUp(() async {
    services = GetIt.asNewInstance();
    database = SqliteDatabase(NativeDatabase.memory());
    identity = _Identity();
    services.registerSingleton<SqliteDatabase>(database);
    services.registerSingleton<NostrIdentityFacade>(identity);
    services.registerSingleton<BullVaultFacade>(_Vaults());
    services.registerSingleton<KeychainManifestFacade>(_Catalog());
    WalletBackupLocator.setup(services);
    await services.unregister<WalletBackupFileRepository>();
    services.registerSingleton<WalletBackupFileRepository>(_Files());
    await services.unregister<WalletBackupSnapshotRepository>();
    services.registerSingleton<WalletBackupSnapshotRepository>(_Snapshots());
    await services.unregister<BullVaultBackupRepository>();
    await services.unregister<WalletInventoryBackupRepository>();
    await services.unregister<WalletMetadataBackupRepository>();
    services.registerSingleton<BullVaultBackupRepository>(_NativeVaults());
    services.registerSingleton<WalletInventoryBackupRepository>(_Wallets());
    services.registerSingleton<WalletMetadataBackupRepository>(_Metadata());
  });
  tearDown(() async {
    await services.reset();
    await database.close();
  });
  test('all screens share the consent request owner', () {
    expect(
      services<SetWalletBackupEnabledUsecase>(),
      same(services<SetWalletBackupEnabledUsecase>()),
    );
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
      final result = await services<WalletBackupFacade>().recoverVaults(
        words: 'invalid',
      );
      expect(result, isA<Err<VaultBackupRecovery?, WalletBackupFailure>>());
      verify(() => identity.fromWords('invalid')).called(1);
      verifyNever(identity.resolve);
    },
  );
}
