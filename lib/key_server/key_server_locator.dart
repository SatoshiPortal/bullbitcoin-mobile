import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/key_server/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/trash_backup_key_from_server_usecase.dart';
import 'package:bb_mobile/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/locator.dart';

class KeyServerLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<StoreBackupKeyIntoServerUsecase>(
      () => StoreBackupKeyIntoServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
        seedRepository: locator<SeedRepository>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
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
        seedRepository: locator<SeedRepository>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
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
      ),
    );
  }
}
