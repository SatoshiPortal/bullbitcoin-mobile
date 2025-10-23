import 'package:bb_mobile/core/recoverbull/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/features/recoverbull/flow.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum RecoverBullRoute {
  recoverbullFlows('/recoverbull-flows');

  final String path;

  const RecoverBullRoute(this.path);
}

class RecoverBullRouter {
  static final route = GoRoute(
    name: RecoverBullRoute.recoverbullFlows.name,
    path: RecoverBullRoute.recoverbullFlows.path,
    builder: (context, state) {
      final RecoverBullFlow flow = state.extra! as RecoverBullFlow;
      return BlocProvider(
        create:
            (context) => RecoverBullBloc(
              flow: flow,
              createEncryptedVaultUsecase:
                  locator<CreateEncryptedVaultUsecase>(),
              storeVaultKeyIntoServerUsecase:
                  locator<StoreVaultKeyIntoServerUsecase>(),
              checkKeyServerConnectionUsecase:
                  locator<CheckKeyServerConnectionUsecase>(),
              fetchVaultKeyFromServerUsecase:
                  locator<FetchVaultKeyFromServerUsecase>(),
              decryptVaultUsecase: locator<DecryptVaultUsecase>(),
              restoreVaultUsecase: locator<RestoreVaultUsecase>(),
            ),
        child: const RecoverBullFlowNavigator(),
      );
    },
  );
}
