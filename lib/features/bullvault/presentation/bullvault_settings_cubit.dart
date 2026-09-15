import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BullVaultSettingsState {
  final bool loading;
  final List<BullVaultRecord> records;
  final BullVaultInspection? inspection;
  final BullVaultFailure? failure;
  const BullVaultSettingsState({
    this.loading = true,
    this.records = const [],
    this.inspection,
    this.failure,
  });
}

final class BullVaultSettingsCubit extends Cubit<BullVaultSettingsState> {
  final InspectBullVaultUsecase _inspect;
  int _request = 0;
  BullVaultSettingsCubit(this._inspect) : super(const BullVaultSettingsState());

  Future<void> load([String? walletId]) async {
    final request = ++_request;
    emit(const BullVaultSettingsState());
    if (walletId == null) {
      final result = await _inspect.list();
      if (isClosed || request != _request) return;
      emit(switch (result) {
        Ok(:final value) => BullVaultSettingsState(
          loading: false,
          records: value,
        ),
        Err(:final failure) => BullVaultSettingsState(
          loading: false,
          failure: failure,
        ),
      });
    } else {
      final result = await _inspect.execute(walletId);
      if (isClosed || request != _request) return;
      emit(switch (result) {
        Ok(:final value) => BullVaultSettingsState(
          loading: false,
          inspection: value,
        ),
        Err(:final failure) => BullVaultSettingsState(
          loading: false,
          failure: failure,
        ),
      });
    }
  }
}
