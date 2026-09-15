import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/record_encrypted_backup_created_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/derive_vault_key_usecase.dart';
import 'package:bb_mobile/core/widgets/secret_reveal_gate.dart';
import 'package:bb_mobile/features/recoverbull/flow.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_tor/tor.dart';

enum RecoverBullRoute {
  recoverbullFlows('/recoverbull-flows');

  final String path;

  const RecoverBullRoute(this.path);
}

class RecoverBullFlowsExtra {
  final RecoverBullFlow flow;
  final EncryptedVault? vault;
  final bool returnToCaller;
  final bool deriveKeyLocally;
  final String? seedFingerprint;

  RecoverBullFlowsExtra({
    required this.flow,
    required this.vault,
    this.returnToCaller = false,
    this.deriveKeyLocally = false,
    this.seedFingerprint,
  });
}

void openRecoverBullFlow(
  BuildContext context, {
  required RecoverBullFlow flow,
  EncryptedVault? vault,
}) => context.goNamed(
  RecoverBullRoute.recoverbullFlows.name,
  extra: RecoverBullFlowsExtra(flow: flow, vault: vault),
);

class RecoverBullRouter {
  static GoRoute route({
    required Future<bool> Function(List<WalletPreferences> preferences)
    onSeedRecovered,
  }) => GoRoute(
    name: RecoverBullRoute.recoverbullFlows.name,
    path: RecoverBullRoute.recoverbullFlows.path,
    builder: (context, state) {
      final RecoverBullFlowsExtra extra = state.extra! as RecoverBullFlowsExtra;

      Widget buildFlow(BuildContext context) => BlocProvider(
        create: (context) => RecoverBullBloc(
          flow: extra.flow,
          returnToCaller: extra.returnToCaller,
          seedFingerprint: extra.seedFingerprint,
          preSelectedVault: extra.vault,
          deriveKeyLocally: extra.deriveKeyLocally,
          pickVaultUsecase: locator<PickVaultUsecase>(),
          saveFileToSystemUsecase: locator<SaveFileToSystemUsecase>(),
          createEncryptedVaultUsecase: locator<CreateEncryptedVaultUsecase>(),
          storeVaultKeyIntoServerUsecase:
              locator<StoreVaultKeyIntoServerUsecase>(),
          recordEncryptedBackupCreatedUsecase:
              locator<RecordEncryptedBackupCreatedUsecase>(),
          checkKeyServerConnectionUsecase:
              locator<CheckServerConnectionUsecase>(),
          connectToKeyServerUsecase: locator<ConnectToKeyServerUsecase>(),
          fetchVaultKeyFromServerUsecase:
              locator<FetchVaultKeyFromServerUsecase>(),
          decryptVaultUsecase: locator<DecryptVaultUsecase>(),
          deriveVaultKeyUsecase: DeriveVaultKeyUsecase(
            GetAllSeedsUsecase(seedRepository: locator<SeedRepository>()),
            locator<RecoverBullRepository>(),
          ),
          restoreVaultUsecase: locator<RestoreVaultUsecase>(),
          onSeedRecovered: onSeedRecovered,
          connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
          saveToGoogleDriveUsecase: locator<SaveVaultToGoogleDriveUsecase>(),
          ensureRecoverBullTorSessionUsecase:
              locator<EnsureRecoverBullTorSessionUsecase>(),
          walletBloc: context.read(),
          fetchLatestGoogleDriveVaultUsecase:
              locator<FetchLatestGoogleDriveVaultUsecase>(),
          updateLatestEncryptedVaultTestUsecase:
              locator<UpdateLatestEncryptedVaultTestUsecase>(),
          watchTorConnectionUsecase: locator<WatchTorConnectionUsecase>(),
        ),
        child: RecoverBullFlowNavigator(
          viewKeyMethodSelection:
              extra.flow == RecoverBullFlow.viewVaultKey && extra.vault == null,
        ),
      );

      // Neither local seed reads nor a server key request can start until the
      // user authenticates and the capture-protection request has completed.
      if (extra.flow == RecoverBullFlow.viewVaultKey && extra.vault != null) {
        return SecretRevealGate(builder: buildFlow);
      }
      return buildFlow(context);
    },
  );
}
