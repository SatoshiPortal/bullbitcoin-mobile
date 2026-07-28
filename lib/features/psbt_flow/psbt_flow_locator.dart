import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/psbt_flow/domain/generate_psbt_qr_parts_usecase.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_cubit.dart';
import 'package:get_it/get_it.dart';

class PsbtFlowLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerLazySingleton<GeneratePsbtQrPartsUsecase>(
      GeneratePsbtQrPartsUsecase.new,
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactoryParam<ShowAnimatedQrCubit, String, QrType>(
      (psbt, qrType) => ShowAnimatedQrCubit(
        generatePsbtQrPartsUsecase: locator<GeneratePsbtQrPartsUsecase>(),
        psbt: psbt,
        qrType: qrType,
      ),
    );
  }
}
