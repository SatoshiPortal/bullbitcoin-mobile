import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/status_check/domain/check_service_status_usecase.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ServiceStatusCubit extends Cubit<ServiceStatusState> {
  final CheckServiceStatusUsecase _checkServiceStatusUsecase;

  ServiceStatusCubit({required this._checkServiceStatusUsecase})
    : super(const ServiceStatusState());

  Future<void> checkStatus() async {
    emit(state.copyWith(isLoading: true, failure: null));

    switch (await _checkServiceStatusUsecase.execute()) {
      case Ok(:final value):
        if (isClosed) return;
        emit(state.copyWith(serviceStatus: value, isLoading: false));
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }
}
