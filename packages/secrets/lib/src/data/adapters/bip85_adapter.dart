import 'dart:typed_data';

import 'package:convert/convert.dart' as conv;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/crypto/bip85_derivation.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/ports/bip85_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/ark_secret.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';

/// BIP85 derivations. All derivation uses the mainnet master xprv (matches the
/// app's ARK / recoverbull derivation).
class Bip85Adapter implements Bip85Port {
  Bip85Adapter(SecretStorePort store) : _guard = SecretGuard(store);
  final SecretGuard _guard;

  SecretsFailure _err(String log) => DerivationFailure(log);

  String _xprv(Mnemonic m) =>
      Bip32Derivation.xprvFromSeed(m.toSeed().bytes, BitcoinNetwork.mainnet);

  @override
  Future<Result<Bip85Derivation, SecretsFailure>> deriveChildMnemonic({
    required Fingerprint masterSeed,
    required MnemonicLength length,
    required int index,
  }) =>
      _guard.read(masterSeed, (m) async {
        final child = Bip85Crypto.deriveChildMnemonic(
          xprvBase58: _xprv(m),
          length: length,
          index: index,
        );
        return Ok(Bip85Derivation(
          path: Bip85Path(
              Bip85Crypto.childMnemonicPath(length: length, index: index)),
          length: length,
          words: child.words,
        ));
      }, onError: _err);

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
      _guard.read(masterSeed, (m) async {
        final hexStr = Bip85Crypto.deriveHex(
          xprvBase58: _xprv(m),
          numBytes: numBytes,
          index: index,
        );
        return Ok(Bip85HexResult(
          path: Bip85Path("128169'/$numBytes'/$index'"),
          hex: hexStr,
        ));
      }, onError: _err);

  @override
  Future<Result<VaultKey, SecretsFailure>> deriveRecoverbullKey({
    required Fingerprint masterSeed,
    required Bip85Path path,
  }) =>
      _guard.read(masterSeed, (m) async {
        final keyHex = Bip85Crypto.deriveBackupKeyHex(_xprv(m), path.path);
        return Ok(VaultKey(Uint8List.fromList(conv.hex.decode(keyHex))));
      }, onError: _err);

  @override
  Future<Result<ArkSecret, SecretsFailure>> deriveArkSecret({
    required Fingerprint masterSeed,
  }) =>
      _guard.read(masterSeed,
          (m) async => Ok(ArkSecret(Bip85Crypto.deriveArk(_xprv(m)))),
          onError: _err);
}
