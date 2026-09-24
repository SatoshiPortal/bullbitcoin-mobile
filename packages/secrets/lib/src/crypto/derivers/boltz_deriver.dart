import 'package:bull_sdk/boltz.dart' as boltz;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:meta/meta.dart';

/// The swap key boltz derives from a wallet. Reached as `Deriver.boltz`.
///
/// A derivation, not a signer, and it will stay one: the swap key is a
/// delegated credential — a separate mnemonic that `swaps` stores and
/// signs with on its own. See doc/design.md, § Modules.
final class BoltzDeriver {
  @internal
  const BoltzDeriver();

  /// The dedicated swap key for [secret].
  ///
  /// The wallet's own mnemonic never leaves this call — what comes back
  /// is the swap-scoped credential the caller stores and uses from then
  /// on.
  ///
  /// The passphrase takes part, so two secrets that share words get
  /// different swap keys — the derivation the secret's identity implies.
  ///
  /// ⚠️ **Keys already stored were derived from the words alone**, and
  /// nothing re-derives them: a passphrase wallet that has a swap key
  /// keeps it. The caller must not treat this as reproducing a stored
  /// key — `swaps` asks for one only when it holds none. See
  /// doc/design.md, § Passphrase.
  Future<SwapKey> swapKey(
    MnemonicMaterial secret, {
    required BitcoinNetwork network,
  }) async {
    final derived = await boltz.SwapMasterKey.create(
      walletMnemonic: secret.words.join(' '),
      walletPassphrase: secret.passphrase.isEmpty ? null : secret.passphrase,
      network: switch (network) {
        BitcoinNetwork.mainnet => boltz.Network.mainnet,
        // boltz has no signet variant; testnet shares its encoding.
        BitcoinNetwork.testnet ||
        BitcoinNetwork.signet => boltz.Network.testnet,
        BitcoinNetwork.regtest => boltz.Network.regtest,
      },
    );
    return SwapKey(
      xprv: derived.xprv,
      xpub: derived.xpub,
      mnemonic: derived.mnemonic,
      fingerprint: Fingerprint(derived.fingerprint),
      isTestnet: !network.isMainnet,
    );
  }
}
