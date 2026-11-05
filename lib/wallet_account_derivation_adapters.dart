import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:primitives/primitives.dart'
    show BullException, Err, Fingerprint, Ok, Result;
import 'package:secrets/secrets.dart';
import 'package:wallet/wallet.dart';

/// Derives a wallet's public account inside `secrets`: what comes back is an
/// xpub and public descriptors. The seed, the master xprv and the BIP39 words
/// never reach this adapter.
final class SecretWalletAccountDerivationAdapter
    implements WalletAccountDerivationPort {
  final Secrets _secrets;

  const SecretWalletAccountDerivationAdapter(this._secrets);

  @override
  Future<WalletAccountKeys> deriveAccount({
    required Fingerprint secretId,
    required Network network,
    required ScriptType scriptType,
  }) async {
    final secret = _unwrap(await _secrets.fetch(secretId));
    // Each chain with its own SLIP-44 coin type — 0/1 for Bitcoin, 1776/1 for Liquid — as every wallet already on a device was derived. Folding Liquid onto Bitcoin mainnet changed `xpub` and `xpubFingerprint` for every Liquid wallet.
    final xpub = _unwrap(
      await secret.derive.xpub(
        network: network.shared,
        scriptType: scriptType.shared,
      ),
    );

    final String descriptor;
    final String changeDescriptor;
    if (network.isBitcoin) {
      final descriptors = _unwrap(
        await secret.derive.descriptors.bitcoin(
          network: network.bitcoin,
          scriptType: scriptType.shared,
        ),
      );
      descriptor = descriptors.external;
      changeDescriptor = descriptors.internal;
    } else {
      // The confidential descriptor covers both keychains, and a seed-only secret is refused before anything is loaded. Liquid descriptors ignore the passphrase, consistently with signing.
      descriptor = _unwrap(
        await secret.derive.descriptors.liquid(network: network.liquid),
      );
      changeDescriptor = descriptor;
    }

    return WalletAccountKeys(
      xpub: xpub,
      // Public math on a public key: deriving an xpub's own fingerprint needs nothing from the secret.
      xpubFingerprint: Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
      externalDescriptor: descriptor,
      internalDescriptor: changeDescriptor,
    );
  }

  /// Turns a secrets failure into the exception wallet creation has always thrown, so callers keep their existing error handling.
  static T _unwrap<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw MnemonicSeedNeededException(
      failure.toString(),
    ),
  };
}

class MnemonicSeedNeededException extends BullException {
  MnemonicSeedNeededException(super.message);
}
