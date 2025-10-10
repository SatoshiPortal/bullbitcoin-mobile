import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class CreateArkSecretUsecase {
  final Bip85Repository _bip85Repository;

  CreateArkSecretUsecase({required Bip85Repository bip85Repository})
    : _bip85Repository = bip85Repository;

  Future<({String derivation, String hex})> execute({
    required Seed defaultSeed,
  }) async {
    final derivations = await _bip85Repository.fetchAll();
    for (final derivation in derivations) {
      final isHex = derivation.application == Bip85Application.hex;
      final isIndex11811 = derivation.index == Ark.bip85Index;
      if (isHex && isIndex11811) {
        throw ArkDerivationAlreadyExistsError();
      }
    }

    final xprvBase58 = Bip32Derivation.getXprvFromSeed(
      defaultSeed.bytes,
      // Ark support only bitcoin mainnet and signet but BULL does not support signet yet
      Network.bitcoinMainnet,
    );

    final derivation = await _bip85Repository.deriveHex(
      xprvBase58: xprvBase58,
      length: Ark.bip85Length,
      index: Ark.bip85Index,
    );

    return derivation;
  }
}
