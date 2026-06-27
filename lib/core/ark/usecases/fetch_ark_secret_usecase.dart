import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:convert/convert.dart';

class FetchArkSecretUsecase {
  final Bip85Repository _bip85Repository;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  FetchArkSecretUsecase({
    required this._bip85Repository,
    required this._getDefaultSeedUsecase,
  });

  Future<List<int>?> execute() async {
    final List<Bip85DerivationEntity> derivations;
    switch (await _bip85Repository.fetchAll()) {
      case Err():
        return null;
      case Ok(:final value):
        derivations = value;
    }

    Bip85DerivationEntity? arkDerivation;
    for (final derivation in derivations) {
      if (derivation.application == Bip85Application.hex &&
          derivation.index == Ark.bip85Index &&
          derivation.status == Bip85Status.active) {
        arkDerivation = derivation;
      }
    }

    if (arkDerivation == null) return null;

    final defaultSeed = await _getDefaultSeedUsecase.execute();
    final xprvBase58 = Bip32Derivation.getXprvFromSeed(
      defaultSeed.bytes,
      Network.bitcoinMainnet,
    );

    final secretKey = bip85.Bip85Entropy.deriveHex(
      xprvBase58: xprvBase58,
      numBytes: Ark.bip85Length,
      index: Ark.bip85Index,
    );

    return hex.decode(secretKey);
  }
}
