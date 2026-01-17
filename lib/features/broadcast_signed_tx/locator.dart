import 'package:bb_mobile/core/mesh/mesh_service.dart';

class BroadcastSignedTxLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    // Add any use cases here if needed in the future
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactoryParam<BroadcastSignedTxCubit, String?, void>(
      (unsignedPsbt, _) => BroadcastSignedTxCubit(
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
        meshService: locator<MeshService>(),
        unsignedPsbt: unsignedPsbt,
      ),
    );
  }
}
