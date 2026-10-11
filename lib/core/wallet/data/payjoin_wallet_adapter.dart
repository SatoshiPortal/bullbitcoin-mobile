import 'dart:typed_data';

import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

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
    final (secret, metadata, account) = await _loadSecret(walletId, network);
    final wallet = WalletModel.fromMetadata(metadata) as PublicBdkWalletModel;
    final annotated = await _wallet.addOwnDerivations(
      psbt: psbt,
      wallet: wallet,
    );
    final prepared = await _wallet.preparePsbtForSigning(
      annotated,
      foreignInputWallet: wallet,
    );
    final scriptType = metadata.inferredScriptType;
    if (scriptType == null) {
      throw StateError('Payjoin requires a standard local wallet');
    }
    final signed = _unwrap(
      await secret.sign.psbt(
        prepared.psbt,
        network: network,
        scriptType: scriptType.shared,
        accountIndex: account,
      ),
    );
    return _wallet
        .completePsbtSigning(originalPsbt: prepared.psbt, signedPsbt: signed)
        .psbt;
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

  Future<(Secret, WalletMetadataModel, int)> _loadSecret(
    String walletId,
    BitcoinNetwork network,
  ) async {
    final metadata = await _loadMetadata(walletId, network);
    final scriptType = metadata.inferredScriptType;
    if (metadata.signers.length != 1 || scriptType == null) {
      throw StateError('Payjoin requires a standard local wallet');
    }
    final signer = metadata.signers.single;
    if (signer.descriptorKeys.length != 1) {
      throw StateError('Payjoin requires a standard local wallet');
    }
    final key = signer.descriptorKeys.single;
    final account = scriptType.standardAccount(
      key.derivationPath,
      metadata.network,
    );
    if (signer.signer != Signer.local ||
        account == null ||
        key.descriptorPath != standardSingleSignatureDescriptorPath) {
      throw StateError('Payjoin requires a standard local wallet');
    }
    final secret = _unwrap(
      await _secrets.fetch(Fingerprint(key.masterFingerprint)),
    );
    return (secret, metadata, account);
  }

  /// This adapter already reports every problem by throwing — the port has no failure type — so a package failure becomes a `StateError` naming its kind, never its message.
  static T _unwrap<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('secrets: ${failure.runtimeType}'),
  };
}
