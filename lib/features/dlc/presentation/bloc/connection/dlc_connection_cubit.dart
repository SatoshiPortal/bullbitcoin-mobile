import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/check_dlc_connection_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dlc_connection_state.dart';
part 'dlc_connection_cubit.freezed.dart';

class DlcConnectionCubit extends Cubit<DlcConnectionState> {
  DlcConnectionCubit({
    required CheckDlcConnectionUsecase checkDlcConnectionUsecase,
  })  : _checkDlcConnectionUsecase = checkDlcConnectionUsecase,
        super(const DlcConnectionState());

  final CheckDlcConnectionUsecase _checkDlcConnectionUsecase;

  Future<void> checkConnection() async {
    emit(state.copyWith(isChecking: true, error: null));
    try {
      final status = await _checkDlcConnectionUsecase.execute();
      emit(state.copyWith(isChecking: false, connectionStatus: status));
    } on Exception catch (e) {
      emit(
        state.copyWith(
          isChecking: false,
          connectionStatus: const DlcConnectionStatus(
            apiHealth: DlcApiHealth.unreachable,
            message: 'Health check failed',
          ),
          error: e,
        ),
      );
    }
  }
}
