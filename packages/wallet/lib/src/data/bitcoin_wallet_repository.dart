import 'dart:typed_data';

import 'package:primitives/primitives.dart' show NetworkFee, RelativeFee;
import 'package:wallet/wallet.dart';

import 'package:transaction_sync/transaction_sync.dart';

class BitcoinWalletRepository implements BitcoinSendPort {
  final WalletCatalogPort _walletMetadataDatasource;
  final WalletSigningPort _signing;
  final BdkWalletDatasource _bdkWallet;
  final WalletFreezeStorePort _frozenUtxos;
  final WalletSourceOperationCoordinator _coordinator;

  BitcoinWalletRepository({
    required this._walletMetadataDatasource,
    required this._signing,
    required BdkWalletDatasource bdkWalletDatasource,
    required WalletFreezeStorePort frozenWalletUtxoDatasource,
    required this._coordinator,
  }) : _bdkWallet = bdkWalletDatasource,
       _frozenUtxos = frozenWalletUtxoDatasource;

  @override
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>? unspendable,
    List<WalletCoinPort>? selected,
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
    if (selected != null &&
        selected.isNotEmpty &&
        spendableSelected!.length != selected.length) {
      throw NoSpendableUtxoException(
        'At least one selected UTXO is unspendable',
      );
    }

    final psbt = await _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _bdkWallet.buildPsbt(
        wallet: wallet,
        address: address,
        amountSat: amountSat,
        networkFee: networkFee,
        drain: drain,
        // An empty merged list is equivalent to null for the datasource
        // (it gates on isNotEmpty), so always pass the merge.
        unspendable: mergedUnspendable,
        selected: spendableSelected,
        // Default to RBF-enabled, matching both the datasource default and
        // BDK's own default sequence (0xFFFFFFFD). `?? false` would disable
        // RBF for any caller omitting the flag — harmless while
        // setExactSequence's result was discarded, wrong now that it works.
        replaceByFee: replaceByFee ?? true,
      ),
    );

    return psbt;
  }

  /// Signs through [WalletSigningPort]: the host's secret store holds the
  /// key, so this package never sees a mnemonic or a private wallet model.
  Future<String> signPsbt(String psbt, {required String walletId}) async {
    final metadata = await _bitcoinMetadata(walletId);
    return _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _signing.signPsbt(psbt, walletId: walletId),
    );
  }

  WalletSourceKey _sourceKey(WalletMetadata metadata) => WalletSourceKey(
    metadata.id,
    'bitcoin',
    metadata.isTestnet ? 'testnet' : 'mainnet',
  );

  Future<WalletMetadata> _bitcoinMetadata(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    return metadata;
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

    final isFromWallet = await _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _bdkWallet.isMine(script, wallet: wallet),
    );

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

    final isFromWallet = await _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _bdkWallet.isAddressMine(address, wallet: wallet),
    );

    return isFromWallet;
  }

  @override
  Future<int> getTxSize({required String psbt}) async {
    final txSize = await const WalletPsbtInspection().decodeTxSize(psbt);
    return txSize;
  }

  Future<int> getTxFeeAmount({required String psbt}) async {
    final feeAbsolute = await const WalletPsbtInspection().getFeeAmount(psbt);
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
    return await const WalletPsbtInspection().getAmountSentToAddress(
      psbt,
      address,
      isTestnet: metadata.isTestnet,
    );
  }

  Future<({BigInt satoshis, int transactions})> dryScan({
    required List<int> entropy,
    required String passphrase,
    required ScriptType scriptType,
    required bool isTestnet,
    required WalletConnectionPort electrumServer,
  }) {
    return _bdkWallet.dryScan(
      entropy: entropy,
      passphrase: passphrase,
      scriptType: scriptType,
      isTestnet: isTestnet,
      electrumServer: electrumServer,
    );
  }

  /// Verifies the stored transaction's wallet-owned input signatures against
  /// its watch-only descriptors (GHSA-6jp4-8v48-cc5v guard); no key material
  /// is loaded. See [BdkWalletDatasource.verifyTransactionInputSignatures].
  Future<TransactionSignatureStatus> getTransactionSignatureStatus({
    required String walletId,
    required String txid,
  }) async {
    final metadata = await _bitcoinMetadata(walletId);
    return _coordinator.runExclusive(
      _sourceKey(metadata),
      (_) => _verifyInputSignaturesUncoordinated(metadata, txid),
    );
  }

  Future<TransactionSignatureStatus> _verifyInputSignaturesUncoordinated(
    WalletMetadata metadata,
    String txid,
  ) => _bdkWallet.verifyTransactionInputSignatures(
    txid: txid,
    wallet: WalletModel.fromMetadata(metadata),
  );

  Future<String> bumpFee({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
  }) async {
    final metadata = await _bitcoinMetadata(walletId);
    return _coordinator.runExclusive(_sourceKey(metadata), (_) async {
      final signatureStatus = await _verifyInputSignaturesUncoordinated(
        metadata,
        txid,
      );
      switch (signatureStatus) {
        case TransactionSignatureStatus.valid:
          break;
        case TransactionSignatureStatus.invalid:
          throw ManipulatedTransactionException(
            'Input signature verification failed for the stored transaction',
          );
        case TransactionSignatureStatus.unverifiable:
          throw UnverifiableTransactionException(
            'Input signatures of the stored transaction could not be verified',
          );
      }
      return _signing.bumpFee(
        walletId: walletId,
        txid: txid,
        newFeeRate: newFeeRate,
      );
    });
  }
}
