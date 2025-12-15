import 'package:bb_mobile/core_deprecated/ark/ark.dart';
import 'package:bb_mobile/core_deprecated/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core_deprecated/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core_deprecated/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core_deprecated/utils/bip32_derivation.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:convert/convert.dart';

class FetchArkSecretUsecase {
  final Bip85Repository _bip85Repository;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  FetchArkSecretUsecase({
    required Bip85Repository bip85Repository,
    required GetDefaultSeedUsecase getDefaultSeedUsecase,
  }) : _bip85Repository = bip85Repository,
       _getDefaultSeedUsecase = getDefaultSeedUsecase;

  Future<List<int>?> execute() async {
    final derivations = await _bip85Repository.fetchAll();
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
