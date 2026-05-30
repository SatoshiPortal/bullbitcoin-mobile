import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/application/trezor_device_repository.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

/// Prepares a Trezor-backed watch-only descriptor entity, ready to hand to
/// the import_watch_only_wallet feature's finalize screen.
class PrepareTrezorImportUsecase {
  final TrezorDeviceRepository _trezorRepository;

  PrepareTrezorImportUsecase({required TrezorDeviceRepository trezorRepository})
    : _trezorRepository = trezorRepository;

  Future<WatchOnlyDescriptorEntity> execute({
    required TrezorAccount account,
    String? label,
  }) async {
    try {
      final masterFingerprint = await _trezorRepository.getMasterFingerprint();

      final descriptor = satoshifier.Descriptor.fromStrings(
        fingerprint: masterFingerprint,
        path: account.derivationPath,
        xpub: account.xpub,
      );

      final watchOnlyDescriptor = satoshifier.WatchOnlyDescriptor(
        descriptor: descriptor,
      );

      return WatchOnlyWalletEntity.descriptor(
            watchOnlyDescriptor: watchOnlyDescriptor,
            signerDevice: SignerDeviceEntity.trezor,
            label: label ?? 'Trezor Wallet',
          )
          as WatchOnlyDescriptorEntity;
    } on TrezorApplicationError {
      rethrow;
    } catch (e) {
      throw TrezorApplicationError.unknown(e.toString());
    }
  }
}
