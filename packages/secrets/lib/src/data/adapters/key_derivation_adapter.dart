import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/crypto/descriptor_derivation.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/seed_secret.dart';
import 'package:secrets/src/domain/key_derivation_port.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// Reads the seed via `useAndForget` and derives public keys/descriptors. Lives
/// in `src/crypto` — the lint allow-list zone for `useAndForget`.
class KeyDerivationPortImpl implements KeyDerivationPort {
  KeyDerivationPortImpl(this._store);
  final SecretStore _store;

  String _key(Fingerprint fp) => SecretStoreKeys.seedKey(fp.hex);

  @override
  Future<Result<Fingerprint, SecretsFailure>> masterFingerprint(
          Fingerprint seed) =>
      _guard(seed, (s) async => Ok(s.fingerprint));

  @override
  Future<Result<Xpub, SecretsFailure>> accountXpub({
    required Fingerprint seed,
    required ScriptType scriptType,
    required bool isTestnet,
    required int account,
  }) =>
      _guard(seed, (s) async {
        final network =
            Network.fromEnvironment(isTestnet: isTestnet, isLiquid: false);
        final acct = Bip32Derivation.accountXpub(
          seedBytes: s.seedBytes,
          scriptType: scriptType,
          network: network,
          account: account,
        );
        final type = scriptType.getXpubType(network);
        return Ok(Xpub(
          value: Bip32Derivation.convertXpub(acct, type),
          type: type,
        ));
      });

  @override
  Future<Result<BitcoinDescriptor, SecretsFailure>> bitcoinDescriptor({
    required Fingerprint seed,
    required ScriptType scriptType,
    required bool isTestnet,
  }) =>
      _guard(seed, (s) async {
        final network = isTestnet
            ? Network.bitcoinTestnet
            : Network.bitcoinMainnet;
        final xprv = Bip32Derivation.xprvFromSeed(s.seedBytes, network);
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
      });

  @override
  Future<Result<LiquidDescriptor, SecretsFailure>> liquidDescriptor({
    required Fingerprint seed,
    required bool isTestnet,
  }) async {
    return _guardNullable<LiquidDescriptor>(seed, (s) async {
      if (s is! MnemonicSeedSecret) {
        return const Err<LiquidDescriptor, SecretsFailure>(
            NotAMnemonicSeedFailure(
                'Liquid descriptor requires a mnemonic seed'));
      }
      final ct = await DescriptorDerivation.publicLiquidDescriptorFromMnemonic(
        s.words.join(' '),
        isTestnet: isTestnet,
      );
      return Ok(LiquidDescriptor(ct));
    });
  }

  /// Reads the seed and runs [derive], converting foreign exceptions ONCE.
  Future<Result<T, SecretsFailure>> _guard<T>(
    Fingerprint seed,
    Future<Result<T, SecretsFailure>> Function(SeedSecret) derive,
  ) =>
      _guardNullable(seed, derive);

  Future<Result<T, SecretsFailure>> _guardNullable<T>(
    Fingerprint seed,
    Future<Result<T, SecretsFailure>> Function(SeedSecret) derive,
  ) async {
    try {
      return await _store.useAndForget(
        _key(seed),
        (bytes) => derive(SeedSecret.fromStorageBytes(bytes)),
      );
    } on KeychainLockedException catch (e) {
      return Err(KeychainLockedFailure(sanitizeLog(e.toString())));
    } on SecretNotFoundException {
      return Err(SeedNotFoundFailure(seed));
    } on Exception catch (e) {
      return Err(DerivationFailure(sanitizeLog(e.toString())));
    }
  }
}
