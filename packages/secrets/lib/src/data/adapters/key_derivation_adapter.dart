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

  SecretsFailure _err(String log) => DerivationFailure(log);

  @override
  Future<Result<Fingerprint, SecretsFailure>> masterFingerprint(
          Fingerprint seed) =>
      _guard.read(seed, (m) async => Ok(m.fingerprint), onError: _err);

  @override
  Future<Result<Xpub, SecretsFailure>> accountXpub({
    required Fingerprint seed,
    required ScriptType scriptType,
    required bool isTestnet,
    required int account,
  }) =>
      _guard.read(seed, (m) async {
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
      }, onError: _err);

  @override
  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required Fingerprint seed,
    required ScriptType scriptType,
    required bool isTestnet,
  }) =>
      _guard.read(seed, (m) async {
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
        return Ok(BitcoinDescriptor(external: external, internal: internal));
      }, onError: _err);

  @override
  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({
    required Fingerprint seed,
    required bool isTestnet,
  }) =>
      _guard.read(seed, (m) async {
        final ct = await DescriptorDerivation.publicLiquidDescriptorFromMnemonic(
          m.words.join(' '),
          isTestnet: isTestnet,
        );
        return Ok(LiquidDescriptor(ct));
      }, onError: _err);
}
