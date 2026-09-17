import 'dart:typed_data';

import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

final class PayjoinWalletAdapter implements PayjoinWalletPort {
  final Secrets _secrets;
  final BdkWalletDatasource _wallet;
  final WalletMetadataDatasource _metadata;

  const PayjoinWalletAdapter(this._secrets, this._wallet, this._metadata);

  @override
  Future<String> signPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async {
    final (secret, metadata) = await _loadSecret(walletId, network);
    // The receiver's own input in a payjoin proposal carries no derivation
    // path, and the package signs only what it can derive: the watch-only
    // view adds the paths first.
    final annotated = await _wallet.addOwnDerivations(
      psbt: psbt,
      wallet: WalletModel.fromMetadata(metadata),
    );
    return _unwrap(
      await secret.sign.psbt(
        annotated,
        network: network,
        scriptType: metadata.scriptType.shared,
      ),
    );
  }

  @override
  Future<bool Function(Uint8List script)> createOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    // Ownership is answered from the public descriptors; no key is needed, and none is loaded. Same watch-only view as the outpoint checker below.
    final metadata = await _loadMetadata(walletId, network);
    final wallet = WalletModel.fromMetadata(metadata);
    return _wallet.createIsMineChecker(wallet: wallet);
  }

  @override
  Future<bool Function(Outpoint outpoint)> createOutpointOwnershipChecker({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    // A watch-only view is enough: ownership is answered from the local index,
    // no key material involved.
    final metadata = await _loadMetadata(walletId, network);
    final wallet = WalletModel.fromMetadata(metadata);
    return _wallet.createOutpointIsMineChecker(wallet: wallet);
  }

  @override
  Future<String Function(String psbt)> createPsbtProcessor({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    // The callback captures a signing wallet built inside the package; it is not the seed, but it is a live signing capability. Bounding its lifetime with an explicit close is pending (lot 3); today it lives as long as the receiver holds it, as the previous private wallet did.
    final (secret, metadata) = await _loadSecret(walletId, network);
    return _unwrap(
      await secret.sign.psbtSigner(
        network: network,
        scriptType: metadata.scriptType.shared,
      ),
    );
  }

  @override
  Future<List<PayjoinUtxo>> spendableUtxos({
    required String walletId,
    required BitcoinNetwork network,
  }) async {
    final metadata = await _loadMetadata(walletId, network);
    final wallet = WalletModel.fromMetadata(metadata);
    final utxos = await _wallet.getUtxos(wallet: wallet);
    return utxos.whereType<BitcoinWalletUtxoModel>().map((utxo) {
      return PayjoinUtxo(
        outpoint: (txId: utxo.txId, vout: utxo.vout),
        value: Sats(utxo.amountSat),
        scriptPubkey: utxo.scriptPubkey,
        confirmed: utxo.confirmations > 0,
      );
    }).toList();
  }

  Future<WalletMetadataModel> _loadMetadata(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = await _metadata.fetch(walletId);
    if (metadata == null || !metadata.isBitcoin) {
      throw StateError('Bitcoin wallet metadata not found');
    }
    if (metadata.isTestnet == network.isMainnet) {
      throw StateError('Wallet network does not match Payjoin network');
    }
    return metadata;
  }

  Future<(Secret, WalletMetadataModel)> _loadSecret(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = await _loadMetadata(walletId, network);
    final fingerprint = metadata.seedFingerprint;
    if (fingerprint == null) {
      throw Exception('No secret for wallet: not a seed-derived wallet');
    }
    final secret = _unwrap(await _secrets.fetch(fingerprint));
    if (!secret.info.isMnemonic) {
      throw StateError('Payjoin requires a local mnemonic wallet');
    }
    return (secret, metadata);
  }

  /// This adapter already reports every problem by throwing — the port has no failure type — so a package failure becomes a `StateError` naming its kind, never its message.
  static T _unwrap<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('secrets: ${failure.runtimeType}'),
  };
}
