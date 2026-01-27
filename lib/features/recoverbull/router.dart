import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_wallet_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/recoverbull/flow.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

enum RecoverBullRoute {
  recoverbullFlows('/recoverbull-flows');

  final String path;

  const RecoverBullRoute(this.path);
}

class RecoverBullFlowsExtra {
  final RecoverBullFlow flow;
  final EncryptedVault? vault;

  RecoverBullFlowsExtra({required this.flow, required this.vault});
}

class RecoverBullRouter {
  static final route = GoRoute(
    name: RecoverBullRoute.recoverbullFlows.name,
    path: RecoverBullRoute.recoverbullFlows.path,
    builder: (context, state) {
      final RecoverBullFlowsExtra extra = state.extra! as RecoverBullFlowsExtra;

      return BlocProvider(
        create: (context) => RecoverBullBloc(
          flow: extra.flow,
          preSelectedVault: extra.vault,
          createEncryptedVaultUsecase: sl<CreateEncryptedVaultUsecase>(),
          storeVaultKeyIntoServerUsecase: sl<StoreVaultKeyIntoServerUsecase>(),
          checkKeyServerConnectionUsecase: sl<CheckServerConnectionUsecase>(),
          fetchVaultKeyFromServerUsecase: sl<FetchVaultKeyFromServerUsecase>(),
          decryptVaultUsecase: sl<DecryptVaultUsecase>(),
          restoreVaultUsecase: sl<RestoreVaultUsecase>(),
          connectToGoogleDriveUsecase: sl<ConnectToGoogleDriveUsecase>(),
          saveToGoogleDriveUsecase: sl<SaveVaultToGoogleDriveUsecase>(),
          initializeTorUsecase: sl<InitTorUsecase>(),
          checkWalletStatusUsecase: sl<TheDirtyUsecase>(),
          checkLiquidWalletStatusUsecase: sl<TheDirtyLiquidUsecase>(),
          walletBloc: context.read(),
          fetchLatestGoogleDriveVaultUsecase:
              sl<FetchLatestGoogleDriveVaultUsecase>(),
          updateLatestEncryptedVaultTestUsecase:
              sl<UpdateLatestEncryptedVaultTestUsecase>(),
          torStatusUsecase: sl<TorStatusUsecase>(),
          torConfigPort: sl<TorConfigPort>(),
        ),
        child: const RecoverBullFlowNavigator(),
      );
    },
  );
}
