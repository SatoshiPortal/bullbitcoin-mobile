import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;

class CreateArkSecretUsecase {
  final Bip85Repository _bip85Repository;
  final SettingsRepository _settingsRepository;

  CreateArkSecretUsecase({
    required Bip85Repository bip85Repository,
    required SettingsRepository settingsRepository,
  }) : _bip85Repository = bip85Repository,
       _settingsRepository = settingsRepository;

  Future<({String derivation, String hex})> execute({
    required Seed defaultSeed,
  }) async {
    final settings = await _settingsRepository.fetch();
    if (settings.isDevModeEnabled != true) {
      throw ArkRequiresDevModeError();
    }

    final derivations = await _bip85Repository.fetchAll();

    Bip85DerivationEntity? existingArkDerivation;

    for (final derivation in derivations) {
      final isHex = derivation.application == Bip85Application.hex;
      final isIndex11811 = derivation.index == Ark.bip85Index;
      if (isHex && isIndex11811) {
        existingArkDerivation = derivation;
        break;
      }
    }

    // If a revoked derivation exists, reactivate it
    if (existingArkDerivation != null) {
      if (existingArkDerivation.status == Bip85Status.revoked) {
        await _bip85Repository.activate(existingArkDerivation);
        final xprvBase58 = Bip32Derivation.getXprvFromSeed(
          defaultSeed.bytes,
          Network.bitcoinMainnet,
        );
        final hex = bip85.Bip85Entropy.deriveHex(
          xprvBase58: xprvBase58,
          numBytes: Ark.bip85Length,
          index: Ark.bip85Index,
        );
        return (derivation: existingArkDerivation.path, hex: hex);
      } else {
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
