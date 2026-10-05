import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart' as convert;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/fingerprint_deriver.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:meta/meta.dart';

/// BIP352 silent payment derivations. Reached as `Deriver.bip352`.
///
/// Works from the seed, so a bytes-only secret serves it; whether a
/// seed-only entry may use it is the operation's decision, not this
/// file's. The passphrase takes part, as it does for every Bitcoin
/// derivation in this package.
final class Bip352Deriver {
  @internal
  const Bip352Deriver();

  /// The scan credential of account 0, as the two descriptors a watch-only
  /// bwk account is opened from.
  ///
  /// BIP352 derives both keys under `m/352'/coin'/0'` — scan at `/1'/0`,
  /// spend at `/0'/0` — with coin type 0 on mainnet and 1 on every test
  /// chain. The silent payment descriptor is BIP392's `sp(scan, spend)` with
  /// the scan private key as a compressed WIF and the spend key as its
  /// compressed public point: the spend private key is computed and dropped
  /// here, and bwk refuses a descriptor that carries it.
  ///
  /// Both strings are spelled exactly as bwk-dart's own test fixtures build
  /// them (`rust/tests/common/mod.rs`): no checksum, origin in apostrophe
  /// notation, multipath `<0;1>` taproot keychains.
  SilentPaymentDescriptors scanKey(
    SecretMaterial secret, {
    required BitcoinNetwork network,
  }) {
    final root = bip32.Bip32Keys.fromSeed(
      secret.seedBytes,
      network: _networkType(network),
    );
    final coin = network.coinType;
    final base = "m/352'/$coin'/0'";
    final scan = root.derivePath("$base/1'/0");
    final spend = root.derivePath("$base/0'/0");
    final fingerprint = const FingerprintDeriver().fingerprint(
      secret.seedBytes,
    );
    final origin = "86'/$coin'/0'";
    final account = root.derivePath('m/$origin').neutered.toBase58();
    return SilentPaymentDescriptors(
      sp: 'sp(${scan.toWIF()},${convert.hex.encode(spend.public)})',
      taproot: 'tr([${fingerprint.hex}/$origin]$account/<0;1>/*)',
      network: network,
      fingerprint: fingerprint,
    );
  }
}

// BIP32 and WIF version bytes bwk parses: xprv, xpub and a mainnet WIF on
// mainnet; tprv, tpub and a test-network WIF on every test chain.
bip32.NetworkType _networkType(BitcoinNetwork network) =>
    network.isMainnet ? _mainnet : _testnet;

final _mainnet = bip32.NetworkType(
  wif: 0x80,
  bip32: bip32.Bip32Type(public: 0x0488b21e, private: 0x0488ade4),
);
final _testnet = bip32.NetworkType(
  wif: 0xef,
  bip32: bip32.Bip32Type(public: 0x043587cf, private: 0x04358394),
);
