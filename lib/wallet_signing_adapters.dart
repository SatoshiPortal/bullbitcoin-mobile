import 'package:primitives/primitives.dart' as primitives;
import 'package:secrets/secrets.dart';
import 'package:wallet/wallet.dart';

/// Signs with the wallet's own key, which never leaves `secrets`.
///
/// The package builds the signing wallet, signs, and throws it away; this adapter holds no private wallet model, so the mnemonic has no reason to exist here.
final class WalletSigningAdapter implements WalletSigningPort {
  final Secrets _secrets;
  final WalletCatalogPort _catalog;
  final BdkWalletDatasource _bdk;

  const WalletSigningAdapter(this._secrets, this._catalog, this._bdk);

  @override
  Future<String> signPsbt(String psbt, {required String walletId}) async {
    final metadata = await _bitcoinMetadata(walletId);
    return _signBitcoin(psbt, metadata);
  }

  @override
  Future<String> bumpFee({
    required String walletId,
    required String txid,
    required primitives.RelativeFee newFeeRate,
  }) async {
    final metadata = await _bitcoinMetadata(walletId);
    // Building an RBF replacement needs the wallet's UTXO set, not its key: the public descriptors are enough. Signing happens after, inside `secrets`.
    final psbt = await _bdk.createUnsignedReplaceByFeePsbt(
      wallet: WalletModel.fromMetadata(metadata),
      txid: txid,
      feeRate: newFeeRate,
    );
    return _signBitcoin(psbt, metadata);
  }

  @override
  Future<String> signPset(
    String pset, {
    required WalletMetadata metadata,
  }) async {
    // The mnemonic stays inside `secrets`: it builds the lwk wallet in a scratch directory it removes afterwards, signs, and returns only the signed PSET.
    final secret = await secretFor(_secrets, metadata);
    return switch (await secret.sign.pset(
      pset,
      network: liquidNetworkOf(metadata.network),
    )) {
      primitives.Ok(:final value) => value,
      primitives.Err(:final failure) => throw Exception(
        'Failed to sign PSET: $failure',
      ),
    };
  }

  Future<WalletMetadata> _bitcoinMetadata(String walletId) async {
    final metadata = await _catalog.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    return metadata;
  }

  Future<String> _signBitcoin(String psbt, WalletMetadata metadata) async {
    final secret = await secretFor(_secrets, metadata);
    return switch (await secret.sign.psbt(
      psbt,
      network: bitcoinNetworkOf(metadata.network),
      scriptType: secretScriptTypeOf(metadata.scriptType),
    )) {
      primitives.Ok(:final value) => value,
      primitives.Err(:final failure) => throw Exception(
        'Failed to sign PSBT: $failure',
      ),
    };
  }
}

/// The stored master fingerprint as a [primitives.Fingerprint], or null when it is not one — a watch-only wallet imported from a descriptor keeps the key origin verbatim, which may be uppercase or absent. Parsed rather than constructed so a signing path reports "no secret" instead of raising.
primitives.Fingerprint? seedFingerprintOf(WalletMetadata metadata) =>
    primitives.Fingerprint.tryParse(metadata.masterFingerprint);

/// The [Secret] that signs for [metadata]'s wallet; throws when the wallet is not seed-derived or its secret cannot be fetched.
Future<Secret> secretFor(Secrets secrets, WalletMetadata metadata) async {
  final fingerprint = seedFingerprintOf(metadata);
  if (fingerprint == null) {
    throw Exception('No secret for wallet: not a seed-derived wallet');
  }
  return switch (await secrets.fetch(fingerprint)) {
    primitives.Ok(:final value) => value,
    primitives.Err(:final failure) => throw Exception(
      'No secret for wallet: $failure',
    ),
  };
}

/// The Bitcoin network [network] names; throws for a Liquid value, since the caller has already branched wrong.
primitives.BitcoinNetwork bitcoinNetworkOf(Network network) =>
    switch (network) {
      Network.bitcoinMainnet => primitives.BitcoinNetwork.mainnet,
      Network.bitcoinTestnet => primitives.BitcoinNetwork.testnet,
      _ => throw ArgumentError.value(
        network,
        'network',
        'not a Bitcoin network',
      ),
    };

/// The Liquid network [network] names; throws for a Bitcoin value.
primitives.LiquidNetwork liquidNetworkOf(Network network) => switch (network) {
  Network.liquidMainnet => primitives.LiquidNetwork.mainnet,
  Network.liquidTestnet => primitives.LiquidNetwork.testnet,
  _ => throw ArgumentError.value(network, 'network', 'not a Liquid network'),
};

/// The wallet's [ScriptType] as the `primitives` one `secrets` speaks.
primitives.ScriptType secretScriptTypeOf(ScriptType scriptType) =>
    switch (scriptType) {
      ScriptType.bip84 => primitives.ScriptType.bip84,
      ScriptType.bip49 => primitives.ScriptType.bip49,
      ScriptType.bip44 => primitives.ScriptType.bip44,
    };
