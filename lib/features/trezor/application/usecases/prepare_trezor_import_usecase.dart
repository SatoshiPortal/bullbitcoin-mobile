import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/trezor/application/application_errors.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

/// Prepares a Trezor-backed watch-only descriptor entity, ready to hand to
/// the import_watch_only_wallet feature's finalize screen.
class PrepareTrezorImportUsecase {
  const PrepareTrezorImportUsecase();

  Future<WatchOnlyDescriptorEntity> execute({
    required TrezorAccount account,
    String? label,
  }) async {
    try {
      final descriptor = satoshifier.Descriptor.fromStrings(
        fingerprint: account.masterFingerprint,
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
    } catch (e) {
      throw TrezorApplicationError.unknown(e.toString());
    }
  }
}
