import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_section.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

DateTime _systemNowUtc() => DateTime.now().toUtc();

final class BuildWalletBackupEnvelopeUsecase {
  final KeychainManifestFacade _keychainManifest;
  final WalletMetadataBackup? _metadata;
  final DateTime Function() _nowUtc;

  const BuildWalletBackupEnvelopeUsecase(
    this._keychainManifest, {
    this._metadata,
    this._nowUtc = _systemNowUtc,
  });

  @useResult
  Future<Result<WalletBackupEnvelope, WalletBackupFailure>> execute({
    required String parentFingerprint,
    String? remoteMetadataPayload,
    bool allowEmpty = false,
  }) async {
    final fingerprint = Fingerprint.tryParse(parentFingerprint);
    if (fingerprint == null) {
      return const Err(WalletBackupParentFingerprintMismatchFailure());
    }
    final manifestResult = await _keychainManifest.buildManifestFilePayload(
      fingerprint,
      allowEmpty: allowEmpty,
    );
    final String manifestPayload;
    switch (manifestResult) {
      case Ok(:final value):
        manifestPayload = value;
      case Err(:final failure):
        return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
    }

    final metadataResult = _metadata == null
        ? null
        : await _metadata.compose(
            parentFingerprint: fingerprint.hex,
            remotePayload: remoteMetadataPayload,
          );
    if (metadataResult case Err(:final failure)) {
      return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
    }
    final metadataPayload = switch (metadataResult) {
      null => null,
      Ok(:final value) => value,
      Err() => null,
    };
    final createdAt = _nowUtc().millisecondsSinceEpoch ~/ 1000;
    return Ok(
      WalletBackupEnvelope(
        parentFingerprint: fingerprint.hex,
        createdAt: createdAt,
        manifest: WalletBackupManifestSection(
          payload: manifestPayload,
          parentFingerprint: fingerprint.hex,
        ),
        metadata: metadataPayload == null
            ? null
            : WalletBackupMetadataSection(
                payload: metadataPayload,
                parentFingerprint: fingerprint.hex,
              ),
      ),
    );
  }
}
