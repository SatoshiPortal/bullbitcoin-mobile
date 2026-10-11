import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_menu_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class BullVaultSettingsState {
  const BullVaultSettingsState();
}

final class BullVaultSettingsLoading extends BullVaultSettingsState {
  const BullVaultSettingsLoading();
}

final class BullVaultMenuLoaded extends BullVaultSettingsState {
  final List<BullVaultRecord> records;
  const BullVaultMenuLoaded(this.records);
}

final class BullVaultInspectionLoaded extends BullVaultSettingsState {
  final BullVaultInspection inspection;
  const BullVaultInspectionLoaded(this.inspection);
}

final class BullVaultSettingsFailed extends BullVaultSettingsState {
  final BullVaultFailure failure;
  const BullVaultSettingsFailed(this.failure);
}

final class BullVaultSettingsCubit extends Cubit<BullVaultSettingsState> {
  final LoadBullVaultMenuUsecase _loadMenu;
  final InspectBullVaultUsecase _inspect;
  int _request = 0;
  BullVaultSettingsCubit(this._loadMenu, this._inspect)
    : super(const BullVaultSettingsLoading());
  Future<void> load([String? walletId]) async {
    final request = ++_request;
    emit(const BullVaultSettingsLoading());
    final BullVaultSettingsState loaded;
    if (walletId == null) {
      loaded = switch (await _loadMenu.execute()) {
        Ok(:final value) => BullVaultMenuLoaded(value),
        Err(:final failure) => BullVaultSettingsFailed(failure),
      };
    } else {
      loaded = switch (await _inspect.execute(walletId)) {
        Ok(:final value) => BullVaultInspectionLoaded(value),
        Err(:final failure) => BullVaultSettingsFailed(failure),
      };
    }
    if (isClosed || request != _request) return;
    emit(loaded);
  }
}
