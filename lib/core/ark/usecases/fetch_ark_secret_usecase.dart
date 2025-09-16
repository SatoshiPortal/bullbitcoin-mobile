import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip85/bip85.dart' as bip85;
import 'package:convert/convert.dart';

class FetchArkSecretUsecase {
  final Bip85Repository _bip85Repository;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  FetchArkSecretUsecase({
    required Bip85Repository bip85Repository,
    required GetDefaultSeedUsecase getDefaultSeedUsecase,
  }) : _bip85Repository = bip85Repository,
       _getDefaultSeedUsecase = getDefaultSeedUsecase;

  Future<List<int>> execute() async {
    final derivations = await _bip85Repository.fetchAll();
    Bip85DerivationEntity? arkDerivation;
    for (final derivation in derivations) {
      if (derivation.application == Bip85Application.hex &&
          derivation.index == Ark.bip85Index) {
        arkDerivation = derivation;
      }
    }

    if (arkDerivation == null) throw ArkDerivationNotFoundError();

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
