import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ServiceStatusCubit extends Cubit<ServiceStatusState> {
  final CheckAllServiceStatusUsecase _checkAllServiceStatusUsecase;
  final GetWalletsUsecase _getWalletsUsecase;

  ServiceStatusCubit({
    required CheckAllServiceStatusUsecase checkAllServiceStatusUsecase,
    required GetWalletsUsecase getWalletsUsecase,
  }) : _checkAllServiceStatusUsecase = checkAllServiceStatusUsecase,
       _getWalletsUsecase = getWalletsUsecase,
       super(const ServiceStatusState());

  Future<void> checkStatus() async {
    try {
      emit(state.copyWith(isLoading: true, error: null));

      final wallets = await _getWalletsUsecase.execute();
      final defaultWallet = wallets.firstWhere((w) => w.isDefault);
      final network = defaultWallet.network;

      final serviceStatus = await _checkAllServiceStatusUsecase.execute(
        network: network,
      );

      emit(state.copyWith(serviceStatus: serviceStatus, isLoading: false));
    } catch (e) {
      log.severe('[ServiceStatusCubit] Failed to check service status: $e', trace: StackTrace.current);
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void clearError() => emit(state.copyWith(error: null));
}
