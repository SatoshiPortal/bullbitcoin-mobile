import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:meta/meta.dart';

final class BackupCredentialResolver {
  final GetSettingsUsecase _getSettings;
  final WalletRepository _wallets;
  final Secrets _secrets;

  const BackupCredentialResolver({
    required this._getSettings,
    required this._wallets,
    required this._secrets,
  });

  @useResult
  Future<Result<Secret, NostrIdentityFailure>> defaultSecret() async {
    try {
      final settings = await _getSettings.execute();
      final wallets = await _wallets.getWallets(
        environment: settings.environment,
        onlyDefaults: true,
        onlyBitcoin: true,
      );
      final fingerprint = switch (wallets) {
        Ok(:final value) => value.firstOrNull?.singleLocalSeedFingerprint,
        Err() => null,
      };
      final id = Fingerprint.tryParse(fingerprint ?? '');
      if (id == null) return const Err(BackupCredentialUnavailable());
      return (await _secrets.fetch(
        id,
      )).mapErr((_) => const BackupCredentialUnavailable());
    } on Exception {
      return const Err(BackupCredentialUnavailable());
    }
  }

  @useResult
  Future<Result<BackupCredential, NostrIdentityFailure>> resolve() async {
    return switch (await defaultSecret()) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => (await value.backup.data()).mapErr(
        (_) => const BackupCredentialUnavailable(),
      ),
    };
  }

  @useResult
  Result<BackupCredential, NostrIdentityFailure> fromWords(String input) {
    try {
      return Ok(BackupCredential.fromWords(input));
    } on Exception {
      return const Err(InvalidDataRecoveryWords());
    }
  }
}
