import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_deriver.dart';
import 'package:flutter/foundation.dart';

/// [PassphraseWalletDeriver] over the wallet metadata and descriptor domain.
///
/// The combined public descriptor and the wallet id both come from the same
/// derivation, so identity is the descriptor rather than the four-byte
/// fingerprint the record also carries (spec 6.5).
final class BdkPassphraseWalletDeriver implements PassphraseWalletDeriver {
  const BdkPassphraseWalletDeriver();

  @override
  Future<PassphraseWalletDerivation> derive({
    required MnemonicSeed parentSeed,
    required String passphrase,
    required Network network,
  }) async {
    // PBKDF2 over 2048 rounds drops frames on the entry screen; the seed store
    // moves the same call off the UI thread for the same reason.
    final derived = await compute(
      _deriveSeed,
      SeedModel.mnemonic(
        mnemonicWords: parentSeed.mnemonicWords,
        passphrase: passphrase,
      ),
    );
    if (derived is! MnemonicSeed) {
      throw StateError('Passphrase derivation produced a non-mnemonic seed');
    }
    try {
      final metadata = await WalletMetadataService.deriveFromSeed(
        seed: derived,
        network: network,
        scriptType: ScriptType.bip84,
        isDefault: false,
        provenance: WalletProvenance.defaultSeedPassphrase,
        seedPassphraseUsed: true,
      );
      return PassphraseWalletDerivation(
        walletId: metadata.id,
        combinedPublicDescriptor:
            DescriptorDerivation.combinePublicBitcoinDescriptors(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              network: network,
            ),
        seed: derived,
      );
    } catch (_) {
      // Nobody has taken ownership yet, so the half-derived material dies here.
      derived.bytes.fillRange(0, derived.bytes.length, 0);
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  static Seed _deriveSeed(SeedModel model) => model.toEntity();
}
