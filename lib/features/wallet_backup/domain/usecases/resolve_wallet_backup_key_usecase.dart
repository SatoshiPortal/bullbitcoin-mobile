import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:meta/meta.dart';

typedef WalletBackupKey = ({
  String parentFingerprint,
  WalletBackupEncryptionKey encryptionKey,
});

final class ResolveWalletBackupKeyUsecase {
  final GetSettingsUsecase _settings;
  final GetDefaultSeedUsecase _defaultSeed;

  const ResolveWalletBackupKeyUsecase(this._settings, this._defaultSeed);

  @useResult
  Future<Result<WalletBackupKey, WalletBackupFailure>> execute() async {
    try {
      final settings = await _settings.execute();
      final Seed seed;
      switch (await _defaultSeed.execute(environment: settings.environment)) {
        case Ok(:final value):
          seed = value;
        case Err():
          return const Err(WalletBackupWalletUnavailableFailure());
      }
      final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
        xprvBase58: Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes),
        path: bip85.Bip85HardenedPath(
          Bip85Reservations.walletBackupEncryptionKey.path,
        ),
      );
      return Ok((
        parentFingerprint: seed.masterFingerprint.toLowerCase(),
        encryptionKey: WalletBackupEncryptionKey(entropy.substring(0, 64)),
      ));
    } on Exception catch (error, trace) {
      log.warning(
        'Wallet backup key derivation failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupKeyDerivationFailure());
    }
  }
}
