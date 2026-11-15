import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart'
    show ParseSignerExportUsecase, ParseWatchOnlyInputUsecase;
import 'package:bb_mobile/features/labels/labels_facade.dart' show LabelsFacade;
import 'package:bb_mobile/features/scan_anything/domain/usecases/check_silent_payment_send_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_history.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/check_swap_source_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/find_imported_wallet_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/import_scanned_labels_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart' show SpFacade;
import 'package:bb_mobile/features/scan_anything/data/scan_parsers.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/decode_bbqr_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/identify_scanned_content_usecase.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_cubit.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart'
    show DetectBitcoinStringUsecase;
import 'package:get_it/get_it.dart';

class ScanAnythingLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CheckSilentPaymentSendUsecase>(
      () => CheckSilentPaymentSendUsecase(spFacade: locator<SpFacade>()),
    );
    locator.registerFactory<ImportScannedLabelsUsecase>(
      () => ImportScannedLabelsUsecase(labelsFacade: locator<LabelsFacade>()),
    );
    locator.registerLazySingleton<ScanHistory>(ScanHistory.new);
    locator.registerFactory<CheckSwapSourceUsecase>(
      () => CheckSwapSourceUsecase(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
      ),
    );
    locator.registerFactory<FindImportedWalletUsecase>(
      () => FindImportedWalletUsecase(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
      ),
    );
    locator.registerFactory<IdentifyScannedContentUsecase>(
      () => IdentifyScannedContentUsecase(
        parseWatchOnlyInputUsecase: locator<ParseWatchOnlyInputUsecase>(),
        parseSignerExportUsecase: locator<ParseSignerExportUsecase>(),
        detectBitcoinStringUsecase: locator<DetectBitcoinStringUsecase>(),
        canSendSilentPayment: locator<CheckSilentPaymentSendUsecase>().execute,
        findImportedWallet: locator<FindImportedWalletUsecase>().execute,
        hasSwapSource: locator<CheckSwapSourceUsecase>().execute,
        isRawTransaction: parsesAsBitcoinTransaction,
      ),
    );
    locator.registerFactory<DecodeBbqrUsecase>(
      () => const DecodeBbqrUsecase(join: joinBbqrParts),
    );
    locator.registerFactory<ScanAnythingCubit>(
      () => ScanAnythingCubit(
        identifyScannedContentUsecase: locator<IdentifyScannedContentUsecase>(),
        decodeBbqrUsecase: locator<DecodeBbqrUsecase>(),
        importScannedLabelsUsecase: locator<ImportScannedLabelsUsecase>(),
        decodeImage: decodeQrImage,
        history: locator<ScanHistory>(),
      ),
    );
  }
}
