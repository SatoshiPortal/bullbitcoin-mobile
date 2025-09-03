import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_vault_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/key_server/data/services/backup_key_service.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/trash_backup_key_from_server_usecase.dart';
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/locator.dart';

class KeyServerLocator {
  static void setup() {
    // Registering services
    locator.registerLazySingleton<BackupKeyService>(
      () => BackupKeyService(
        seedRepository: locator<SeedRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    // Use cases
    locator.registerFactory<StoreBackupKeyIntoServerUsecase>(
      () => StoreBackupKeyIntoServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
        backupService: locator<BackupKeyService>(),
      ),
    );

    locator.registerFactory<CheckKeyServerConnectionUsecase>(
      () => CheckKeyServerConnectionUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );

    locator.registerFactory<TrashBackupKeyFromServerUsecase>(
      () => TrashBackupKeyFromServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );

    locator.registerFactory<DeriveBackupKeyFromDefaultWalletUsecase>(
      () => DeriveBackupKeyFromDefaultWalletUsecase(
        backupKeyService: locator<BackupKeyService>(),
      ),
    );

    locator.registerFactory<RestoreBackupKeyFromPasswordUsecase>(
      () => RestoreBackupKeyFromPasswordUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<KeyServerCubit>(
      () => KeyServerCubit(
        checkServerConnectionUsecase:
            locator<CheckKeyServerConnectionUsecase>(),
        storeBackupKeyIntoServerUsecase:
            locator<StoreBackupKeyIntoServerUsecase>(),
        trashKeyFromServerUsecase: locator<TrashBackupKeyFromServerUsecase>(),
        deriveBackupKeyFromDefaultWalletUsecase:
            locator<DeriveBackupKeyFromDefaultWalletUsecase>(),
        restoreBackupKeyFromPasswordUsecase:
            locator<RestoreBackupKeyFromPasswordUsecase>(),
        createVaultKeyFromDefaultSeedUsecase:
            locator<CreateVaultKeyFromDefaultSeedUsecase>(),
      ),
    );
  }
}
