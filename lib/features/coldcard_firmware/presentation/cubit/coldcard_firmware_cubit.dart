import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/cancel_coldcard_firmware_download_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/download_and_verify_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/get_latest_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/save_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_state.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart' show ColdcardModel;
import 'package:flutter_bloc/flutter_bloc.dart';

class ColdcardFirmwareCubit extends Cubit<ColdcardFirmwareState> {
  ColdcardFirmwareCubit({
    required GetLatestColdcardFirmwareUsecase getLatestColdcardFirmwareUsecase,
    required DownloadAndVerifyColdcardFirmwareUsecase
    downloadAndVerifyColdcardFirmwareUsecase,
    required SaveColdcardFirmwareUsecase saveColdcardFirmwareUsecase,
    required CancelColdcardFirmwareDownloadUsecase
    cancelColdcardFirmwareDownloadUsecase,
  }) : _getLatest = getLatestColdcardFirmwareUsecase,
       _downloadAndVerify = downloadAndVerifyColdcardFirmwareUsecase,
       _save = saveColdcardFirmwareUsecase,
       _cancelDownload = cancelColdcardFirmwareDownloadUsecase,
       super(const ColdcardFirmwareState());

  final GetLatestColdcardFirmwareUsecase _getLatest;
  final DownloadAndVerifyColdcardFirmwareUsecase _downloadAndVerify;
  final SaveColdcardFirmwareUsecase _save;
  final CancelColdcardFirmwareDownloadUsecase _cancelDownload;

  @override
  Future<void> close() async {
    // Leaving the flow aborts an in-flight download.
    _cancelDownload.execute();
    await super.close();
  }

  Future<void> loadLatest(ColdcardModel model) async {
    emit(
      state.copyWith(
        status: ColdcardFirmwareStatus.fetchingLatest,
        model: model,
        latestRelease: null,
        downloadedBytes: 0,
        totalBytes: null,
        failure: null,
        isExporting: false,
        exportSucceeded: false,
        exportFailure: null,
      ),
    );
    final result = await _getLatest.execute(model);
    if (isClosed) return;
    result.fold(
      (release) => emit(
        state.copyWith(
          status: ColdcardFirmwareStatus.latestReady,
          latestRelease: release,
        ),
      ),
      (failure) => emit(
        state.copyWith(
          status: ColdcardFirmwareStatus.failure,
          failure: failure,
        ),
      ),
    );
  }

  Future<void> downloadAndVerify() async {
    if (state.latestRelease == null || state.isBusy) return;
    emit(
      state.copyWith(
        status: ColdcardFirmwareStatus.downloading,
        downloadedBytes: 0,
        totalBytes: null,
        failure: null,
      ),
    );
    final result = await _downloadAndVerify.execute(
      onProgress: (received, total) {
        if (isClosed) return;
        emit(state.copyWith(downloadedBytes: received, totalBytes: total));
      },
      onVerifying: () {
        if (isClosed) return;
        emit(state.copyWith(status: ColdcardFirmwareStatus.verifying));
      },
    );
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(status: ColdcardFirmwareStatus.verified)),
      (failure) => emit(
        state.copyWith(
          status: ColdcardFirmwareStatus.failure,
          failure: failure,
        ),
      ),
    );
  }

  Future<void> exportFirmware() async {
    if (state.status != ColdcardFirmwareStatus.verified || state.isExporting) {
      return;
    }
    emit(
      state.copyWith(
        isExporting: true,
        exportSucceeded: false,
        exportFailure: null,
      ),
    );
    final result = await _save.execute();
    if (isClosed) return;
    result.fold(
      (saved) => emit(
        // saved == false means the user cancelled the picker — not a success, not an error.
        state.copyWith(isExporting: false, exportSucceeded: saved),
      ),
      (failure) =>
          emit(state.copyWith(isExporting: false, exportFailure: failure)),
    );
  }

  void clearExportFlags() {
    emit(state.copyWith(exportSucceeded: false, exportFailure: null));
  }

  void retry() {
    final model = state.model;
    // A discovery failure means our idea of "latest" may be stale — re-discover instead of re-downloading the same release forever.
    final mustRediscover =
        state.latestRelease == null ||
        state.failure is ColdcardFirmwareDiscoveryFailure;
    if (mustRediscover) {
      if (model != null) loadLatest(model);
    } else {
      downloadAndVerify();
    }
  }
}
