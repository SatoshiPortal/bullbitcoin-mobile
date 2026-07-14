import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_device.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_firmware_release_entity.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/verified_coldcard_firmware_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'coldcard_firmware_state.freezed.dart';

enum ColdcardFirmwareStatus {
  initial,
  fetchingLatest,
  latestReady,
  downloading,
  verifying,
  verified,
  failure,
}

@freezed
sealed class ColdcardFirmwareState with _$ColdcardFirmwareState {
  const factory ColdcardFirmwareState({
    @Default(ColdcardFirmwareStatus.initial) ColdcardFirmwareStatus status,
    ColdcardDevice? device,
    ColdcardFirmwareReleaseEntity? latestRelease,
    @Default(0) int downloadedBytes,
    int? totalBytes,
    VerifiedColdcardFirmwareEntity? verifiedFirmware,
    ColdcardFirmwareFailure? failure,
    @Default(false) bool isExporting,
    // One-shot flags consumed by a BlocListener (snackbars on the success screen); cleared via clearExportFlags().
    @Default(false) bool exportSucceeded,
    ColdcardFirmwareFailure? exportFailure,
  }) = _ColdcardFirmwareState;
  const ColdcardFirmwareState._();

  bool get isBusy =>
      status == ColdcardFirmwareStatus.fetchingLatest ||
      status == ColdcardFirmwareStatus.downloading ||
      status == ColdcardFirmwareStatus.verifying;

  /// null while the total is unknown (no content length) — show an indeterminate bar then.
  double? get downloadProgress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (downloadedBytes / total).clamp(0.0, 1.0);
  }
}
