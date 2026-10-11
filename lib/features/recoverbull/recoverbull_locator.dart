import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/derive_vault_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/check_recoverbull_backup_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:get_it/get_it.dart';

abstract final class RecoverBullLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<DeriveVaultKeyUsecase>(
      () => DeriveVaultKeyUsecase(
        locator<PickVaultUsecase>(),
        locator<GetAllSeedsUsecase>(),
        locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<ConnectToKeyServerUsecase>(
      () => ConnectToKeyServerUsecase(
        locator<CheckServerConnectionUsecase>(),
        locator<EnsureRecoverBullTorSessionUsecase>(),
      ),
    );
    locator.registerLazySingleton<RecoverBullFacade>(
      () => RecoverBullFacade(
        CheckRecoverBullBackupUsecase(locator<GetWalletsUsecase>()),
      ),
    );
  }
}
