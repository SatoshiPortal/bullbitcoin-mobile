import 'dart:typed_data';

import 'package:convert/convert.dart' as conv;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/crypto/bip85_derivation.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/seed_secret.dart';
import 'package:secrets/src/domain/bip85_port.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/ark_secret.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// BIP85 derivations. All derivation uses the mainnet master xprv (matches the
/// app's ARK / recoverbull derivation). Lives in `src/crypto`.
class Bip85PortImpl implements Bip85Port {
  Bip85PortImpl(this._store);
  final SecretStore _store;

  String _key(Fingerprint fp) => SecretStoreKeys.seedKey(fp.hex);

  String _xprv(SeedSecret s) =>
      Bip32Derivation.xprvFromSeed(s.seedBytes, Network.bitcoinMainnet);

  @override
  Future<Result<Bip85Derivation, SecretsFailure>> deriveChildMnemonic({
    required Fingerprint masterSeed,
    required MnemonicLength length,
    required int index,
  }) =>
      _guard(masterSeed, (s) async {
        final child = Bip85Crypto.deriveChildMnemonic(
          xprvBase58: _xprv(s),
          length: length,
          index: index,
        );
        return Ok(Bip85Derivation(
          path: Bip85Path(
              Bip85Crypto.childMnemonicPath(length: length, index: index)),
          kind: SeedKind.mnemonic,
          length: length,
          words: child.words,
        ));
      });

  @override
  Future<Result<Bip85Derivation, SecretsFailure>> deriveBip39Child({
    required Fingerprint masterSeed,
    required Bip85Application app,
    required int index,
    required MnemonicLength length,
  }) {
    if (app != Bip85Application.bip39) {
      return Future.value(const Err(NotAMnemonicSeedFailure(
          'deriveBip39Child requires the bip39 application')));
    }
    return deriveChildMnemonic(
        masterSeed: masterSeed, length: length, index: index);
  }

  @override
  Future<Result<Bip85HexResult, SecretsFailure>> deriveHex({
    required Fingerprint masterSeed,
    required int numBytes,
    required int index,
  }) =>
      _guard(masterSeed, (s) async {
        final hexStr = Bip85Crypto.deriveHex(
          xprvBase58: _xprv(s),
          numBytes: numBytes,
          index: index,
        );
        return Ok(Bip85HexResult(
          path: Bip85Path("128169'/$numBytes'/$index'"),
          hex: hexStr,
        ));
      });

  @override
  Future<Result<BackupKey, SecretsFailure>> deriveRecoverbullKey({
    required Fingerprint masterSeed,
    required Bip85Path path,
  }) =>
      _guard(masterSeed, (s) async {
        final keyHex = Bip85Crypto.deriveBackupKeyHex(_xprv(s), path.path);
        return Ok(BackupKey(Uint8List.fromList(conv.hex.decode(keyHex))));
      });

  @override
  Future<Result<ArkSecret, SecretsFailure>> deriveArkSecret({
    required Fingerprint masterSeed,
  }) =>
      _guard(masterSeed,
          (s) async => Ok(ArkSecret(Bip85Crypto.deriveArk(_xprv(s)))));

  Future<Result<T, SecretsFailure>> _guard<T>(
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
