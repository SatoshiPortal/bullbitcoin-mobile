import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

class GetDefaultSeedUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  GetDefaultSeedUsecase({
    required this._walletRepository,
    required this._seedRepository,
  });

  @useResult
  Future<Result<Seed, SeedFailure>> execute({Environment? environment}) async {
    final List<String> fingerprints;
    try {
      fingerprints = await _walletRepository
          .getDefaultBitcoinWalletFingerprints(environment: environment);
    } on Exception catch (error, trace) {
      log.warning(
        'Default wallet lookup failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DefaultSeedWalletLookupFailure());
    }
    if (fingerprints.isEmpty) return const Err(DefaultSeedNotFoundFailure());
    if (fingerprints.length > 1) {
      return const Err(DefaultSeedAmbiguousFailure());
    }

    final walletFingerprint = Fingerprint.tryParse(fingerprints.single);
    if (walletFingerprint == null) {
      return const Err(DefaultSeedFingerprintMismatchFailure());
    }

    final Seed seed;
    try {
      seed = await _seedRepository.get(walletFingerprint.hex);
    } on Exception catch (error, trace) {
      log.warning(
        'Default seed unavailable',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(DefaultSeedUnavailableFailure());
    }

    final storedFingerprint = Fingerprint.tryParse(seed.masterFingerprint);
    final derivedFingerprint = Fingerprint.tryParse(
      hex.encode(bip32.Bip32Keys.fromSeed(seed.bytes).fingerprint),
    );
    if (storedFingerprint != walletFingerprint ||
        derivedFingerprint != walletFingerprint) {
      return const Err(DefaultSeedFingerprintMismatchFailure());
    }
    return Ok(seed);
  }
}
