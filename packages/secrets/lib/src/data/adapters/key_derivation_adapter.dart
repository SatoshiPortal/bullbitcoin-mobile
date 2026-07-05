import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/crypto/descriptor_derivation.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/domain/ports/key_derivation_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';

/// Reads the seed via [SecretGuard] and derives public keys/descriptors.
class KeyDerivationAdapter implements KeyDerivationPort {
  KeyDerivationAdapter(SecretStorePort store) : _guard = SecretGuard(store);
  final SecretGuard _guard;

  @override
  Future<Result<Fingerprint, SecretsFailure>> masterFingerprint(
          Fingerprint fingerprint) =>
      _guard.read(fingerprint, (m) async => Ok(m.fingerprint), onError: DerivationFailure.new);

  @override
  Future<Result<Xpub, SecretsFailure>> accountXpub({
    required Fingerprint fingerprint,
    required ScriptType scriptType,
    required bool isTestnet,
    required int account,
  }) =>
      _guard.read(fingerprint, (m) async {
        final network =
            isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
        final acct = Bip32Derivation.accountXpub(
          seedBytes: m.toSeed().bytes,
          scriptType: scriptType,
          network: network,
          account: account,
        );
        final type = scriptType.getXpubType(network);
        return Ok(Xpub(
          value: Bip32Derivation.convertXpub(acct, type),
          type: type,
        ));
      }, onError: DerivationFailure.new);

  @override
  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required Fingerprint fingerprint,
    required ScriptType scriptType,
    required bool isTestnet,
  }) =>
      _guard.read(fingerprint, (m) async {
        final network =
            isTestnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
        final xprv = Bip32Derivation.xprvFromSeed(m.toSeed().bytes, network);
        final external = DescriptorDerivation.publicBitcoinDescriptorFromXprv(
          xprv,
          scriptType: scriptType,
          isTestnet: isTestnet,
          internalKeychain: false,
        );
        final internal = DescriptorDerivation.publicBitcoinDescriptorFromXprv(
          xprv,
          scriptType: scriptType,
          isTestnet: isTestnet,
          internalKeychain: true,
        );
        // Defense-in-depth (release path — the derivation's assert is stripped):
        // never hand back a descriptor carrying private key material, whatever a
        // future bdk_dart bump does to toString(). Fail closed instead.
        if (external.contains('prv') || internal.contains('prv')) {
          return const Err(DerivationFailure(
              'derived descriptor unexpectedly contains a private key'));
        }
        return Ok(BitcoinDescriptor(external: external, internal: internal));
      }, onError: DerivationFailure.new);

  @override
  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({
    required Fingerprint fingerprint,
    required bool isTestnet,
  }) =>
      _guard.read(fingerprint, (m) async {
        // LWK derives the confidential descriptor from the BARE mnemonic (no
        // passphrase param), so a hasPassphrase secret would yield the
        // bare-seed Liquid wallet under this passphrase-scoped handle — a
        // DIFFERENT wallet the signer then refuses to sign for (signer_adapter
        // rejects passphrase wallets for exactly this). Returning a watch-only
        // descriptor the package can't spend from is a footgun, so reject it
        // here too — fail closed, consistent with signing/swaps (M2/R2-H2).
        if (m.hasPassphrase) {
          return const Err(DerivationFailure(
              'liquid descriptor is unsupported for passphrase wallets — lwk '
              'derives from the bare mnemonic and would describe a different '
              'wallet than the one this handle signs for'));
        }
        final ct = await DescriptorDerivation.publicLiquidDescriptorFromMnemonic(
          m.words.join(' '),
          isTestnet: isTestnet,
        );
        return Ok(LiquidDescriptor(ct));
      }, onError: DerivationFailure.new);
}
