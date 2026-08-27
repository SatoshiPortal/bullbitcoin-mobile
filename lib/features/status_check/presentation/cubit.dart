import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/status_check/domain/check_service_status_usecase.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ServiceStatusCubit extends Cubit<ServiceStatusState> {
  final CheckServiceStatusUsecase _checkServiceStatusUsecase;
  int _checkGeneration = 0;

  ServiceStatusCubit({required this._checkServiceStatusUsecase})
    : super(const ServiceStatusState());

  Future<void> checkStatus() async {
    final generation = ++_checkGeneration;
    emit(state.copyWith(isLoading: true, failure: null));

    final result = await _checkServiceStatusUsecase.execute(
      initialStatus: state.serviceStatus,
      onUpdate: (serviceStatus) {
        if (generation != _checkGeneration || isClosed) return;
        emit(state.copyWith(serviceStatus: serviceStatus, isLoading: true));
      },
    );

    if (generation != _checkGeneration || isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(serviceStatus: value, isLoading: false));
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  void clearError() => emit(state.copyWith(failure: null));
}
