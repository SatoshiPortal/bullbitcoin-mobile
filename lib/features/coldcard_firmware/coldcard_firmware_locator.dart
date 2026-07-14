import 'package:bb_mobile/features/coldcard_firmware/data/coldcard_firmware_repository_impl.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/cancel_coldcard_firmware_download_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/download_and_verify_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/get_latest_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/save_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_cubit.dart';
import 'package:get_it/get_it.dart';

class ColdcardFirmwareLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ColdcardFirmwareCubit>(() {
      final repository = ColdcardFirmwareRepositoryImpl();
      return ColdcardFirmwareCubit(
        getLatestColdcardFirmwareUsecase: GetLatestColdcardFirmwareUsecase(
          repository: repository,
        ),
        downloadAndVerifyColdcardFirmwareUsecase:
            DownloadAndVerifyColdcardFirmwareUsecase(repository: repository),
        saveColdcardFirmwareUsecase: SaveColdcardFirmwareUsecase(
          repository: repository,
        ),
        cancelColdcardFirmwareDownloadUsecase:
            CancelColdcardFirmwareDownloadUsecase(repository: repository),
      );
    });
  }
}
