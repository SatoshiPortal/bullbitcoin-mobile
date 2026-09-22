import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:meta/meta.dart';
import 'package:convert/convert.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;

class FetchAllBip85DerivationsWithEntropyUsecase {
  final Bip85Repository _bip85Repository;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  FetchAllBip85DerivationsWithEntropyUsecase({
    required this._bip85Repository,
    required this._getDefaultSeedUsecase,
  });

  @useResult
  Future<
    Result<
      List<({Bip85DerivationEntity derivation, String entropy})>,
      Bip85Failure
    >
  >
  execute() async {
    final Seed defaultSeed;
    switch (await _getDefaultSeedUsecase.execute()) {
      case Ok(:final value):
        defaultSeed = value;
      case Err(:final failure):
        log.warning('bip85 derivations: ${failure.logMessage}');
        // The seed layer's vocabulary stops here.
        return Err(
          Bip85UnexpectedFailure('default seed: ${failure.runtimeType}'),
        );
    }

    try {
      final xprvBase58 = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        Network.bitcoinMainnet,
      );

      switch (await _bip85Repository.fetchAll()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final derivationsWithEntropy = value
              .where((e) {
                // A row is bound to the root key that created it.  If that key is
                // no longer available, never show a value derived from another
                // wallet in its place.
                final key = bip32.Bip32Keys.fromBase58(xprvBase58);
                return e.xprvFingerprint.toLowerCase() ==
                    hex.encode(key.fingerprint).toLowerCase();
              })
              .map((e) {
                final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
                  xprvBase58: xprvBase58,
                  path: bip85.Bip85HardenedPath(e.path),
                );
                return (derivation: e, entropy: entropy);
              })
              .toList();
          return Ok(derivationsWithEntropy);
      }
    } catch (e, st) {
      log.severe(
        message: 'FetchAllBip85DerivationsWithEntropyUsecase failed',
        error: e,
        trace: st,
      );
      // Only the runtime type: this block wraps xprv derivation, so an
      // exception message here can carry key material, and `logMessage` is
      // reachable from presentation (#1895).
      return Err(Bip85UnexpectedFailure('derivation: ${e.runtimeType}'));
    }
  }
}
