import 'package:bb_mobile/core/coldcard_firmware/data/coldcard_firmware_repository_impl.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/cancel_coldcard_firmware_download_usecase.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/download_and_verify_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/get_latest_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/usecases/save_coldcard_firmware_usecase.dart';
import 'package:get_it/get_it.dart';

class ColdcardFirmwareCoreLocator {
  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<ColdcardFirmwareRepository>(
      () => ColdcardFirmwareRepositoryImpl(),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetLatestColdcardFirmwareUsecase>(
      () => GetLatestColdcardFirmwareUsecase(
        repository: locator<ColdcardFirmwareRepository>(),
      ),
    );
    locator.registerFactory<DownloadAndVerifyColdcardFirmwareUsecase>(
      () => DownloadAndVerifyColdcardFirmwareUsecase(
        repository: locator<ColdcardFirmwareRepository>(),
      ),
    );
    locator.registerFactory<SaveColdcardFirmwareUsecase>(
      () => SaveColdcardFirmwareUsecase(
        repository: locator<ColdcardFirmwareRepository>(),
      ),
    );
    locator.registerFactory<CancelColdcardFirmwareDownloadUsecase>(
      () => CancelColdcardFirmwareDownloadUsecase(
        repository: locator<ColdcardFirmwareRepository>(),
      ),
    );
  }
}
