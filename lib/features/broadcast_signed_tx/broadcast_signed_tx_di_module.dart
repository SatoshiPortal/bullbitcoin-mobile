import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';

class BroadcastSignedTxDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {}

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactoryParam<BroadcastSignedTxCubit, String?, void>(
      (unsignedPsbt, _) => BroadcastSignedTxCubit(
        broadcastBitcoinTransactionUsecase: sl(),
        unsignedPsbt: unsignedPsbt,
      ),
    );
  }
}
