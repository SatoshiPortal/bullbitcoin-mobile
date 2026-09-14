import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

/// The key this wallet's own backup is sealed with, plus the fingerprint that
/// says whose backup it is.
///
/// The key is the one the twelve backup words derive, so an heir who has only
/// the words opens the same ciphertext (plan 5.2).
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
      return Ok((
        parentFingerprint: seed.masterFingerprint.toLowerCase(),
        encryptionKey: WalletBackupEncryptionKey(
          BackupCredential.fromSeed(seed).encryptionKeyHex,
        ),
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
