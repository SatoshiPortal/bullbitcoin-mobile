import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_key.dart';
import 'package:meta/meta.dart';

enum NostrIdentityPurpose { walletBackup, bullnymAuth, nip05Verification }

class NostrIdentityKeyResolver {
  final GetSettingsUsecase _settings;
  final GetDefaultSeedUsecase _defaultSeed;

  const NostrIdentityKeyResolver(this._settings, this._defaultSeed);

  @useResult
  Future<Result<NostrKey, NostrIdentityFailure>> resolve(
    NostrIdentityPurpose purpose,
  ) async {
    final SettingsEntity settings;
    try {
      settings = await _settings.execute();
    } on Exception catch (error, trace) {
      log.warning(
        'Nostr identity wallet lookup failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(NostrIdentityWalletLookupFailure());
    }

    final seedResult = await _defaultSeed.execute(
      environment: settings.environment,
    );
    final Seed seed;
    switch (seedResult) {
      case Ok(:final value):
        seed = value;
      case Err(:final failure):
        return Err(_mapSeedFailure(failure));
    }

    final path = switch (purpose) {
      NostrIdentityPurpose.walletBackup =>
        Bip85Reservations.nostrWalletBackupKey.path,
      NostrIdentityPurpose.bullnymAuth =>
        Bip85Reservations.nostrBullnymServerAuthKey.path,
      NostrIdentityPurpose.nip05Verification =>
        Bip85Reservations.nostrNip05PublicNymVerificationKey.path,
    };

    final rootXprv = Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes);
    return Ok(NostrKey.derive(rootXprv: rootXprv, path: path));
  }
}

NostrIdentityFailure _mapSeedFailure(SeedFailure failure) => switch (failure) {
  DefaultSeedNotFoundFailure() => const NostrIdentityNoDefaultWalletFailure(),
  DefaultSeedAmbiguousFailure() =>
    const NostrIdentityAmbiguousDefaultWalletFailure(),
  DefaultSeedWalletLookupFailure() => const NostrIdentityWalletLookupFailure(),
  DefaultSeedFingerprintMismatchFailure() =>
    const NostrIdentityFingerprintMismatchFailure(),
  DefaultSeedUnavailableFailure() ||
  SeedFetchFailure() ||
  SeedDeleteFailure() => const NostrIdentitySeedUnavailableFailure(),
};
