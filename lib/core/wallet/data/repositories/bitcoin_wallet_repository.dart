import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';

class BitcoinWalletRepository implements BitcoinSendPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;
  final FrozenWalletUtxoDatasource _frozenUtxos;

  BitcoinWalletRepository({
    required this._walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required FrozenWalletUtxoDatasource frozenWalletUtxoDatasource,
  }) : _seed = seedDatasource,
       _bdkWallet = bdkWalletDatasource,
       _frozenUtxos = frozenWalletUtxoDatasource;

  @override
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool? replaceByFee,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

    // D7 defense in depth: a frozen coin must never be spendable. BDK's
    // documented semantics are the opposite — a manually added utxo
    // (TxBuilder.addUtxos) overrides the unspendable filter — and the
    // datasource deliberately preserves those raw semantics. Enforce the
    // app-level invariant here at the repository boundary, reading the
    // frozen store LIVE at build time, so it holds for ANY caller and
    // any staleness of the caller's earlier utxo fetch — not only for
    // callers going through PrepareBitcoinSendUsecase (which reads the
    // same store plus the payjoin-derived set; payjoin exclusion stays
    // at the usecase because it comes from another repository).
    //
    // The frozen set read here is:
    //  * merged into `unspendable`, so BDK's automatic selection can
    //    never pick a frozen coin even when the caller passed no
    //    exclusion list at all;
    //  * used to strip `selected`, so a frozen coin can't be forced in
    //    as a mandatory input either (the addUtxos override above).
    final frozenRows = await _frozenUtxos.getAllFrozen();
    final unspendableKeys = {
      for (final row in frozenRows) '${row.txId}:${row.vout}',
      for (final outpoint in unspendable ?? const <({String txId, int vout})>[])
        '${outpoint.txId}:${outpoint.vout}',
    };
    final mergedUnspendable = [
      for (final outpoint in {
        for (final row in frozenRows) (txId: row.txId, vout: row.vout),
        ...?unspendable,
      })
        outpoint,
    ];
    final spendableSelected = selected
        ?.where(
          (utxo) => !unspendableKeys.contains('${utxo.txId}:${utxo.vout}'),
        )
        .toList();

    final psbt = await _bdkWallet.buildPsbt(
      wallet: wallet,
      address: address,
      amountSat: amountSat,
      networkFee: networkFee,
      drain: drain,
      // An empty merged list is equivalent to null for the datasource
      // (it gates on isNotEmpty), so always pass the merge.
      unspendable: mergedUnspendable,
      selected: spendableSelected
          ?.map((utxo) => WalletUtxoMapper.fromEntity(utxo))
          .toList(),
      // Default to RBF-enabled, matching both the datasource default and
      // BDK's own default sequence (0xFFFFFFFD). `?? false` would disable
      // RBF for any caller omitting the flag — harmless while
      // setExactSequence's result was discarded, wrong now that it works.
      replaceByFee: replaceByFee ?? true,
    );

    return psbt;
  }

  Future<String> signPsbt(String psbt, {required String walletId}) async {
    final wallet = await getPrivateWallet(walletId: walletId);
    final signedPsbt = await _bdkWallet.signPsbt(wallet: wallet, psbt);
    return signedPsbt;
  }

  Future<bool> isScriptOfWallet({
    required String walletId,
    required Uint8List script,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

    final isFromWallet = await _bdkWallet.isMine(script, wallet: wallet);

    return isFromWallet;
  }

  @override
  Future<bool> isAddressOfWallet(
    String address, {
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

    final isFromWallet = await _bdkWallet.isAddressMine(
      address,
      wallet: wallet,
    );

    return isFromWallet;
  }

  @override
  Future<int> getTxSize({required String psbt}) async {
    final txSize = await _bdkWallet.decodeTxSize(psbt);
    return txSize;
  }

  Future<int> getTxFeeAmount({required String psbt}) async {
    final feeAbsolute = await _bdkWallet.getFeeAmount(psbt);
    return feeAbsolute;
  }

  Future<int> getAmountSentToAddress({
    required String psbt,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    return await _bdkWallet.getAmountSentToAddress(
      psbt,
      address,
      isTestnet: metadata.isTestnet,
    );
  }

  Future<PrivateBdkWalletModel> getPrivateWallet({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final seed =
        await _seed.get(metadata.masterFingerprint) as MnemonicSeedModel;
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet =
        WalletModel.privateBdk(
              id: metadata.id,
              mnemonic: mnemonic,
              passphrase: seed.passphrase,
              scriptType: metadata.scriptType,
              isTestnet: metadata.isTestnet,
            )
            as PrivateBdkWalletModel;
    return wallet;
  }

  Future<({BigInt satoshis, int transactions})> dryScan({
    required List<int> entropy,
    required String passphrase,
    required ScriptType scriptType,
    required bool isTestnet,
    required ElectrumConnection electrumServer,
  }) {
    return _bdkWallet.dryScan(
      entropy: entropy,
      passphrase: passphrase,
      scriptType: scriptType,
      isTestnet: isTestnet,
      electrumServer: electrumServer,
    );
  }

  Future<String> bumpFee({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
  }) async {
    final wallet = await getPrivateWallet(walletId: walletId);
    final psbt = await _bdkWallet.createUnsignedReplaceByFeePsbt(
      wallet: wallet,
      txid: txid,
      feeRate: newFeeRate,
    );
    final signedPsbt = await signPsbt(psbt, walletId: walletId);
    return signedPsbt;
  }
}
