import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class DataBackupContentsState {
  final bool server;
  final bool loading;
  final WalletBackupSnapshot? snapshot;
  final WalletBackupInspection? inspection;
  final BackupSettingsFailure? failure;
  const DataBackupContentsState({
    this.server = false,
    this.loading = false,
    this.snapshot,
    this.inspection,
    this.failure,
  });
}

class DataBackupContentsCubit extends Cubit<DataBackupContentsState> {
  final LoadLocalDataBackupUsecase _local;
  final InspectDataBackupUsecase _server;
  int _request = 0;
  DataBackupContentsCubit(this._local, this._server)
    : super(const DataBackupContentsState());

  Future<void> load({required bool server}) async {
    final request = ++_request;
    emit(DataBackupContentsState(server: server, loading: true));
    if (server) {
      final result = await _server.execute();
      if (isClosed || request != _request) return;
      emit(switch (result) {
        Ok(:final value) => DataBackupContentsState(
          server: true,
          snapshot: value.snapshot,
          inspection: value,
        ),
        Err(:final failure) => DataBackupContentsState(
          server: true,
          failure: failure,
        ),
      });
    } else {
      final result = await _local.execute();
      if (isClosed || request != _request) return;
      emit(switch (result) {
        Ok(:final value) => DataBackupContentsState(snapshot: value),
        Err(:final failure) => DataBackupContentsState(failure: failure),
      });
    }
  }
}
