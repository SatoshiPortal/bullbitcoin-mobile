import 'package:bb_mobile/core_deprecated/recoverbull/domain/usecases/google_drive/delete_drive_file_usecase.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/usecases/google_drive/export_drive_file_usecase.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/presentation/state.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/ui/drive_vaults_list_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum RecoverBullGoogleDriveRoute {
  listDriveVaults('/recoverbull/drive/list');

  final String path;

  const RecoverBullGoogleDriveRoute(this.path);
}

class RecoverBullGoogleDriveRouter {
  static final route = GoRoute(
    name: RecoverBullGoogleDriveRoute.listDriveVaults.name,
    path: RecoverBullGoogleDriveRoute.listDriveVaults.path,
    builder: (context, state) {
      final flow = state.extra! as RecoverBullFlow;

      return BlocProvider(
        create:
            (_) => RecoverBullGoogleDriveBloc(
              flow: flow,
              fetchAllDriveFileMetadataUsecase:
                  locator<FetchAllDriveFileMetadataUsecase>(),
              fetchDriveBackupUsecase: locator<FetchVaultFromDriveUsecase>(),
              deleteDriveFileUsecase: locator<DeleteDriveFileUsecase>(),
              exportDriveFileUsecase: locator<ExportDriveFileUsecase>(),
            ),
        child: BlocListener<
          RecoverBullGoogleDriveBloc,
          RecoverBullGoogleDriveState
        >(
          listenWhen:
              (previous, current) =>
                  previous.selectedVault == null &&
                      current.selectedVault != null ||
                  previous.selectedVault != current.selectedVault,
          listener: (context, state) {
            context.pushNamed(
              RecoverBullRoute.recoverbullFlows.name,
              extra: RecoverBullFlowsExtra(
                flow: flow,
                vault: state.selectedVault,
              ),
            );
          },
          child: const DriveVaultsListPage(),
        ),
      );
    },
  );
}
