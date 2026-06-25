import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:meta/meta.dart';

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
    try {
      final defaultSeed = await _getDefaultSeedUsecase.execute();
      final xprvBase58 = Bip32Derivation.getXprvFromSeed(
        defaultSeed.bytes,
        Network.bitcoinMainnet,
      );

      switch (await _bip85Repository.fetchAll()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final derivationsWithEntropy = value.map((e) {
            final entropy = bip85.Bip85Entropy.deriveFromHardenedPath(
              xprvBase58: xprvBase58,
              path: bip85.Bip85HardenedPath(e.path),
            );
            return (derivation: e, entropy: entropy);
          }).toList();
          return Ok(derivationsWithEntropy);
      }
    } catch (e, st) {
      log.severe(
        message: 'FetchAllBip85DerivationsWithEntropyUsecase failed',
        error: e,
        trace: st,
      );
      return Err(Bip85UnexpectedFailure(e.toString()));
    }
  }
}
