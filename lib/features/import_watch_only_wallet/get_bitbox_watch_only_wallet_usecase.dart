import 'package:meta/meta.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:signers/signers.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/satoshifier.dart' hide Network;

class GetBitBoxWatchOnlyWalletUsecase {
  @useResult
  Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure> execute({
    required SignerAccount account,
    required String label,
  }) {
    try {
      final descriptor = Descriptor.fromStrings(
        fingerprint: account.masterFingerprint,
        path: account.derivationPath,
        xpub: account.xpub,
      );
      final watchOnly = Satoshifier.watchOnlyDescriptor(descriptor: descriptor);
      if (watchOnly is! WatchOnlyDescriptor) {
        return const Err(InvalidFormatFailure());
      }
      return Ok(
        WatchOnlyWalletEntity.descriptor(
          watchOnlyDescriptor: watchOnly,
          signer: SignerEntity.remote,
          label: label,
          signerDevice: account.device,
        ).captureEnvironment(account.network),
      );
    } on WatchOnlyNetworkMismatchException {
      return const Err(NetworkMismatchFailure());
    } catch (_) {
      return const Err(InvalidFormatFailure());
    }
  }
}
