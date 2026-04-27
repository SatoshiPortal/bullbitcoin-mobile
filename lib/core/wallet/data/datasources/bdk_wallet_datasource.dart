import 'dart:async';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/ports/electrum_server_port.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

extension NetworkX on Network {
  bdk.Network get bdkNetwork {
    switch (this) {
      case Network.bitcoinMainnet:
        return bdk.Network.bitcoin;
      case Network.bitcoinTestnet:
        return bdk.Network.testnet;
      default:
        throw UnsupportedBdkNetworkException('$name is not supported by BDK');
    }
  }
}

extension BdkNetworkX on bdk.Network {
  Network get network {
    if (this == bdk.Network.bitcoin) {
      return Network.bitcoinMainnet;
    } else {
      return Network.bitcoinTestnet;
    }
  }
}

class BdkWalletDatasource {
  @visibleForTesting
  final Map<String, int> syncExecutions = {};
  final Map<String, Future<void>> _activeSyncs;
  final StreamController<String> _walletSyncStartedController;
  final StreamController<String> _walletSyncFinishedController;

  BdkWalletDatasource()
    : _activeSyncs = {},
      _walletSyncStartedController = StreamController<String>.broadcast(),
      _walletSyncFinishedController = StreamController<String>.broadcast();

  Stream<String> get walletSyncStartedStream =>
      _walletSyncStartedController.stream;

  Stream<String> get walletSyncFinishedStream =>
      _walletSyncFinishedController.stream;

  bool isWalletSyncing({String? walletId}) => walletId == null
      ? _activeSyncs.isNotEmpty
      : _activeSyncs.containsKey(walletId);

  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final balanceInfo = bdkWallet.balance();

    final balance = BalanceModel(
      confirmedSat: BigInt.from(balanceInfo.confirmed.toSat()),
      immatureSat: BigInt.from(balanceInfo.immature.toSat()),
      trustedPendingSat: BigInt.from(balanceInfo.trustedPending.toSat()),
      untrustedPendingSat: BigInt.from(balanceInfo.untrustedPending.toSat()),
      spendableSat: BigInt.from(balanceInfo.trustedSpendable.toSat()),
      totalSat: BigInt.from(balanceInfo.total.toSat()),
    );

    return balance;
  }

  Future<void> sync({
    required WalletModel wallet,
    required ElectrumServer electrumServer,
  }) {
    // putIfAbsent ensures only one sync starts for each wallet ID,
    //  all others await the same Future.
    // TODO: if needed, add these debugPrint to a filterable logger.debug
    // TODO: to avoid spamming the terminal with recurring prints
    // debugPrint('Sync requested for wallet: ${wallet.id}');
    return _activeSyncs.putIfAbsent(wallet.id, () async {
      try {
        // debugPrint('New sync started for wallet: ${wallet.id}');
        // Notify that the wallet is syncing through a stream for other
        // parts of the app to listen to so they can show a syncing indicator
        _walletSyncStartedController.add(wallet.id);

        // Increment the sync execution count for this wallet for testing purposes
        syncExecutions.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);

        await compute(
          _performFullScan,
          _SyncParams(
            walletId: wallet.id,
            externalDescriptor:
                (wallet as PublicBdkWalletModel).externalDescriptor,
            internalDescriptor: wallet.internalDescriptor,
            isTestnet: wallet.isTestnet,
            electrumUrl: electrumServer.url,
            electrumSocks5: electrumServer.socks5,
            electrumStopGap: electrumServer.stopGap,
            walletHexId: wallet.hexId,
            rootIsolateToken: ServicesBinding.rootIsolateToken!,
          ),
        );
        //debugPrint('Sync completed for wallet: ${wallet.id} with server ${electrumServer.url}',);
      } catch (e) {
        // debugPrint('Sync error for wallet ${wallet.id} with server ${electrumServer.url}: $e');
        rethrow;
      } finally {
        // Notify that the wallet has been synced through a stream for other
        // parts of the app to listen to
        _walletSyncFinishedController.add(wallet.id);
        // Remove the sync so future syncs can be triggered
        // Do not await this, as it is not necessary and can cause deadlocks
        // since it returns the Future from the map.
        // ignore: unawaited_futures
        _activeSyncs.remove(wallet.id);
      }
    });
  }

  Future<bool> isMine(
    Uint8List scriptBytes, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final script = bdk.Script(rawOutputScript: scriptBytes);
    final isMine = bdkWallet.isMine(script: script);

    return isMine;
  }

  /// Returns a synchronous `isMine` check bound to a pre-loaded bdk wallet.
  Future<bool Function(Uint8List)> createIsMineChecker({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    return (Uint8List scriptBytes) =>
        bdkWallet.isMine(script: bdk.Script(rawOutputScript: scriptBytes));
  }

  /// Returns a synchronous PSBT signer bound to a pre-loaded private bdk
  /// wallet.
  Future<String Function(String)> createPsbtSigner({
    required PrivateBdkWalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createPrivateWallet(wallet);
    return (String psbtBase64) {
      final psbt = bdk.Psbt(psbtBase64: psbtBase64);
      bdkWallet.sign(
        psbt: psbt,
        signOptions: bdk.SignOptions(
          trustWitnessUtxo: true,
          assumeHeight: null,
          allowAllSighashes: true,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );
      return psbt.serialize();
    };
  }

  Future<bool> isAddressMine(
    String address, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final bdkAddress = bdk.Address(
      address: address,
      network: wallet.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    final script = bdkAddress.scriptPubkey();
    final isMine = bdkWallet.isMine(script: script);

    return isMine;
  }

  Future<String> buildPsbt({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    List<({String txId, int vout})>? unspendable,
    bool? drain,
    List<WalletUtxoModel>? selected,
    bool replaceByFee = true,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    bdk.TxBuilder txBuilder;

    // Get the scriptPubkey from the address
    final bdkAddress = bdk.Address(
      address: address,
      network: wallet.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    final script = bdkAddress.scriptPubkey();

    // Check if the transaction is a drain transaction
    if (drain == true) {
      txBuilder = bdk.TxBuilder().drainWallet().drainTo(script: script);
    } else {
      if (amountSat == null) {
        throw ArgumentError('amountSat is required');
      }
      txBuilder = bdk.TxBuilder().addRecipient(
        script: script,
        amount: bdk.Amount.fromSat(satoshi: amountSat),
      );
    }

    if (selected != null && selected.isNotEmpty) {
      final selectableOutPoints = selected
          .map(
            (utxo) => bdk.OutPoint(
              txid: bdk.Txid.fromString(hex: utxo.txId),
              vout: utxo.vout,
            ),
          )
          .toList();
      txBuilder.addUtxos(outpoints: selectableOutPoints);
    }

    // bdk_dart always has RBF (nSequence = 0xFFFFFFFD) enabled by default,
    // so we set the sequence to 0xFFFFFFFE if replaceByFee is explicitly set to false to disable RBF.
    if (!replaceByFee) txBuilder.setExactSequence(nsequence: 0xFFFFFFFE);

    if (networkFee.isAbsolute) {
      txBuilder = txBuilder.feeAbsolute(
        feeAmount: bdk.Amount.fromSat(satoshi: networkFee.value.toInt()),
      );
    } else {
      txBuilder = txBuilder.feeRate(
        feeRate: bdk.FeeRate.fromSatPerVb(satVb: networkFee.value.round()),
      );
    }

    // Make sure utxos that are unspendable are not used
    final unspendableOutPoints = unspendable
        ?.map(
          (input) => bdk.OutPoint(
            txid: bdk.Txid.fromString(hex: input.txId),
            vout: input.vout,
          ),
        )
        .toList();

    // TODO: MOVE THIS TO THE TRANSACTION REPOSITORY, the repository should check the unspendable and spendable inputs
    // and build the transaction accordingly or return an error
    if (unspendableOutPoints != null && unspendableOutPoints.isNotEmpty) {
      // Check if there are unspents that are not in unspendableOutpoints so a transaction can be built
      final unspents = bdkWallet.listUnspent();
      final unspendableOutPointsSet = unspendableOutPoints.toSet();
      final unspendableUtxos = unspents.where((utxo) {
        return unspendableOutPointsSet.contains(utxo.outpoint);
      }).toList();

      if (unspendableUtxos.length == unspents.length) {
        throw NoSpendableUtxoException('All unspents are unspendable');
      }

      txBuilder = txBuilder.unspendable(unspendable: unspendableOutPoints);
    }

    // Finish the transaction building process
    final psbt = txBuilder.finish(wallet: bdkWallet);

    return psbt.serialize();
  }

  Future<int> decodeTxSize(String psbtString) async {
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final size = psbt.extractTx().vsize();
    return size.toInt();
  }

  Future<int> getFeeAmount(String psbtString) async {
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final fee = psbt.fee();
    return fee;
  }

  Future<int> getAmountSentToAddress(
    String psbtString,
    String address, {
    required bool isTestnet,
  }) async {
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final tx = psbt.extractTx();
    final outputs = tx.output();
    int totalAmount = 0;
    for (final output in outputs) {
      final scriptPubkey = output.scriptPubkey;
      final outputAddress = bdk.Address.fromScript(
        script: bdk.Script(rawOutputScript: scriptPubkey.toBytes()),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );
      if (outputAddress.toString() == address) {
        totalAmount += output.value.toSat();
      }
    }
    return totalAmount;
  }
  // 25000 - 988

  Future<String> signPsbt(
    String unsignedPsbt, {
    required PrivateBdkWalletModel wallet,
  }) async {
    final psbt = bdk.Psbt(psbtBase64: unsignedPsbt);
    final bdkWallet = await BdkFacade.createPrivateWallet(wallet);

    final isFinalized = bdkWallet.sign(
      psbt: psbt,
      signOptions: bdk.SignOptions(
        trustWitnessUtxo: true,
        assumeHeight: null,
        allowAllSighashes: true,
        tryFinalize: true,
        signWithTapInternalKey: false,
        allowGrinding: true,
      ),
    );
    if (!isFinalized) {
      log.info('Signed PSBT is not finalized');
    } else {
      log.info('Signed PSBT is finalized');
    }

    return psbt.serialize();
  }

  Future<List<WalletUtxoModel>> getUtxos({required WalletModel wallet}) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final unspent = bdkWallet.listUnspent();
    final utxos = await Future.wait(
      unspent.map((unspent) async {
        final address =
            await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
              unspent.txout.scriptPubkey.toBytes(),
              isTestnet: wallet.isTestnet,
            );
        return WalletUtxoModel.bitcoin(
          txId: unspent.outpoint.txid.toString(),
          vout: unspent.outpoint.vout,
          amountSat: BigInt.from(unspent.txout.value.toSat()),
          scriptPubkey: unspent.txout.scriptPubkey.toBytes(),
          // Since it's a BDK utxo, the address should not be null
          // but we return an empty string in case it is for some reason
          address: address ?? '',
          isExternalKeyChain: unspent.keychain == bdk.KeychainKind.external_,
        );
      }),
    );
    return utxos;
  }

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);

    final transactions = bdkWallet.transactions();

    final allTransactionOutputs = await _getAllOutputsOfTransactions(
      transactions,
      wallet: wallet,
    );

    // Map the transactions to WalletTransactionModel
    final List<WalletTransactionModel?> walletTxs = await Future.wait(
      transactions.map((tx) async {
        final (inputs, outputs) = (
          tx.transaction.input(),
          tx.transaction.output(),
        );

        if (toAddress != null && toAddress.isNotEmpty) {
          // Filter transactions by address by returning null for non-matching transactions
          // and then removing null values from the list with whereType at the end of the method
          final matches = await Future.any(
            outputs.map((output) async {
              final address =
                  await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                    output.scriptPubkey.toBytes(),
                    isTestnet: wallet.isTestnet,
                  );
              if (address == null) return false;
              return address == toAddress;
            }),
          ).catchError((_) => false);

          if (!matches) return null;
        }

        // Map inputs and outputs to their respective models
        final inputModels = inputs.asMap().entries.map((entry) {
          final input = entry.value;
          final vin = entry.key;
          final previousOutput = input.previousOutput;
          final output = allTransactionOutputs.firstWhereOrNull(
            (output) =>
                output.txId == previousOutput.txid.toString() &&
                output.vout == previousOutput.vout,
          );

          return TransactionInputModel.bitcoin(
            txId: tx.transaction.computeTxid().toString(),
            vin: vin,
            isOwn: output?.isOwn ?? false,
            scriptSig: input.scriptSig.toBytes(),
            previousTxId: previousOutput.txid.toString(),
            previousTxVout: previousOutput.vout,
          );
        }).toList();
        final outputModels = allTransactionOutputs
            .where(
              (output) =>
                  output.txId == tx.transaction.computeTxid().toString(),
            )
            .toList();

        // Check if all inputs and outputs are owned by the wallet itself
        final isToSelf =
            inputModels.every((input) => input.isOwn) &&
            outputModels.every((output) => output.isOwn);

        final sentAndReceived = bdkWallet.sentAndReceived(tx: tx.transaction);
        final received = sentAndReceived.received.toSat();
        final sent = sentAndReceived.sent.toSat();
        final fee = bdkWallet.calculateFee(tx: tx.transaction).toSat();
        final chainPosition = tx.chainPosition;
        int? confirmationTime;
        if (chainPosition is bdk.ConfirmedChainPosition) {
          final blockTime = chainPosition.confirmationBlockTime;

          confirmationTime = blockTime.confirmationTime;
        }

        final isIncoming = received > sent;
        final netAmountSat = isToSelf
            ? // When sending to self, the fee is paid by this wallet and is
              // the only thing that changes from the balance
              sent - fee
            : isIncoming
            ? // If incoming, fee is paid by sender, so not deducted from
              // wallet's balance
              received - sent
            : // If outgoing, fee is paid by this wallet, so deducted here
              // to know the net amount
              sent - received - fee;

        return WalletTransactionModel(
          txId: tx.transaction.computeTxid().toString(),
          isIncoming: isIncoming,
          amountSat: netAmountSat.toInt(),
          feeSat: fee.toInt(),
          vsize: tx.transaction.vsize().toInt(),
          confirmationTimestamp: confirmationTime,
          isToSelf: isToSelf,
          inputs: inputModels,
          outputs: outputModels,
          isLiquid: false,
          isTestnet: wallet.isTestnet,
          isRbf: tx.transaction.isExplicitlyRbf(),
        );
      }),
    );

    return walletTxs.whereType<WalletTransactionModel>().toList();
  }

  Future<({String address, int index})> getNewAddress({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final addressInfo = bdkWallet.revealNextAddress(
      keychain: isChange
          ? bdk.KeychainKind.internal
          : bdk.KeychainKind.external_,
    );

    // Persist the revealed address to avoid address reuse
    await BdkFacade.saveWallet(bdkWallet, wallet.hexId);

    final index = addressInfo.index;
    final address = addressInfo.address.toString();

    return (index: index, address: address);
  }

  Future<({String address, int index})> getLastRevealedAddressOrNew({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final lastRevealedAddressIndex = await getLastRevealedAddressIndex(
      wallet: wallet,
      isChange: isChange,
    );

    if (lastRevealedAddressIndex < 0) {
      // No address has been revealed yet, so we get a new one
      return getNewAddress(wallet: wallet, isChange: isChange);
    }

    final address = await getAddressByIndex(
      lastRevealedAddressIndex,
      wallet: wallet,
    );

    if (await isAddressUsed(address, wallet: wallet)) {
      // If the last revealed address has been used,
      //  we need to get a new one to avoid address reuse
      return getNewAddress(wallet: wallet, isChange: isChange);
    }

    return (index: lastRevealedAddressIndex, address: address);
  }

  // This can return -1 if no address has been revealed yet.
  // This should be handled accordingly by the caller.
  Future<int> getLastRevealedAddressIndex({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final nextAddress = bdkWallet.revealNextAddress(
      keychain: isChange
          ? bdk.KeychainKind.internal
          : bdk.KeychainKind.external_,
    );

    final index =
        nextAddress.index -
        1; // Subtract 1 to get the last revealed address index

    return index;
  }

  Future<String> getAddressByIndex(
    int index, {
    required WalletModel wallet,
    isChange = false,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final addressInfo = bdkWallet.peekAddress(
      keychain: isChange
          ? bdk.KeychainKind.internal
          : bdk.KeychainKind.external_,
      index: index,
    );

    final address = addressInfo.address.toString();

    return address;
  }

  Future<bool> isAddressUsed(
    String address, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final transactions = bdkWallet.transactions();

    // TODO: Use future.wait to parallelize the loop and improve performance
    for (final tx in transactions) {
      final txOutputs = tx.transaction.output();

      for (final output in txOutputs) {
        final generatedAddress =
            await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
              output.scriptPubkey.toBytes(),
              isTestnet: wallet.isTestnet,
            );
        if (generatedAddress == null) continue;
        if (generatedAddress == address) {
          return true;
        }
      }
    }

    return false;
  }

  Future<Map<String, BigInt>> getAddressBalancesSat({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final utxos = bdkWallet.listUnspent();
    final addressBalances = <String, BigInt>{};

    for (final utxo in utxos) {
      final utxoAddress =
          await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
            utxo.txout.scriptPubkey.toBytes(),
            isTestnet: wallet.isTestnet,
          );
      if (utxoAddress == null) continue;

      addressBalances[utxoAddress] =
          (addressBalances[utxoAddress] ?? BigInt.zero) +
          BigInt.from(utxo.txout.value.toSat());
    }

    return addressBalances;
  }

  Future<List<BitcoinTransactionOutputModel>> _getAllOutputsOfTransactions(
    List<bdk.CanonicalTx> transactions, {
    required WalletModel wallet,
  }) async {
    final listOfOutputs = await Future.wait(
      transactions.map((tx) async {
        final outputs = tx.transaction.output();
        final models = await Future.wait(
          outputs.asMap().entries.map((outputEntry) async {
            final vout = outputEntry.key;
            final output = outputEntry.value;
            final scriptPubkeyBytes = output.scriptPubkey.toBytes();
            final address =
                await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                  output.scriptPubkey.toBytes(),
                  isTestnet: wallet.isTestnet,
                );

            return TransactionOutputModel.bitcoin(
              txId: tx.transaction.computeTxid().toString(),
              vout: vout,
              isOwn: await isMine(scriptPubkeyBytes, wallet: wallet),
              value: BigInt.from(output.value.toSat()),
              scriptPubkey: scriptPubkeyBytes,
              address: address,
            );
          }),
        );
        return models;
      }),
    );

    final allOutputs = listOfOutputs.expand((i) => i).toList();
    return allOutputs.whereType<BitcoinTransactionOutputModel>().toList();
  }

  Future<String> createUnsignedReplaceByFeePsbt({
    required String txid,
    required double feeRate,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final tx = bdk.BumpFeeTxBuilder(
      txid: bdk.Txid.fromString(hex: txid),
      feeRate: bdk.FeeRate.fromSatPerVb(satVb: feeRate.round()),
    );
    final psbt = tx.finish(wallet: bdkWallet);
    return psbt.serialize();
  }

  Future<void> delete({required WalletModel wallet}) async {
    await BdkFacade.delete(wallet);
    log.fine('Deleted wallet ${wallet.id} BDK database');
  }
}

// Top-level function for isolate execution
class _SyncParams {
  final String walletId;
  final String externalDescriptor;
  final String internalDescriptor;
  final bool isTestnet;
  final String electrumUrl;
  final String? electrumSocks5;
  final int electrumStopGap;
  final String walletHexId;
  final RootIsolateToken rootIsolateToken;

  _SyncParams({
    required this.walletId,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.isTestnet,
    required this.electrumUrl,
    required this.electrumSocks5,
    required this.electrumStopGap,
    required this.walletHexId,
    required this.rootIsolateToken,
  });
}

Future<void> _performFullScan(_SyncParams params) async {
  // Initialize the binary messenger for platform channel access in isolate
  // Needed for things like getting the database path from BdkFacade which
  // uses path_provider under the hood
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

  // Recreate wallet model in the isolate
  final wallet = WalletModel.publicBdk(
    id: params.walletId,
    externalDescriptor: params.externalDescriptor,
    internalDescriptor: params.internalDescriptor,
    isTestnet: params.isTestnet,
  );

  final bdkWallet = await BdkFacade.createWallet(wallet);
  // Guard against a rustls CryptoProvider install race across concurrent
  // sync isolates. electrum-client's install_default check+install is not
  // atomic, so two isolates can both see "not installed" and the loser
  // fails. On retry the provider is already installed and the check
  // short-circuits.
  bdk.ElectrumClient buildClient() => bdk.ElectrumClient(
    url: params.electrumUrl,
    // Only set the socks5 if it's not empty,
    //  otherwise bdk will throw an error
    // TODO: this was in bdk_flutter, check if it's still needed in bdk_dart
    socks5: params.electrumSocks5?.isNotEmpty == true
        ? params.electrumSocks5
        : null,
  );
  bdk.ElectrumClient blockchain;
  try {
    blockchain = buildClient();
  } on bdk.CouldNotCreateConnectionElectrumException catch (e) {
    if (e.errorMessage.contains('Failed to install CryptoProvider')) {
      blockchain = buildClient();
    } else {
      rethrow;
    }
  }
  final scanRequest = bdkWallet.startFullScan().build();
  final update = blockchain.fullScan(
    request: scanRequest,
    stopGap: params.electrumStopGap,
    batchSize:
        20, // TODO: Should we make `batchSize` configurable in electrumSettings as well?
    fetchPrevTxouts:
        true, // TODO: Should we make `fetchPrevTxouts` configurable in electrumSettings as well?
  );
  // Apply update to the wallet in memory
  bdkWallet.applyUpdate(update: update);
  // Persist the updated wallet to the database
  await BdkFacade.saveWallet(bdkWallet, params.walletHexId);
}

class FailedToSignPsbtException extends BullException {
  FailedToSignPsbtException(super.message);
}

class UnsupportedBdkNetworkException extends BullException {
  UnsupportedBdkNetworkException(super.message);
}

class NoSpendableUtxoException extends BullException {
  NoSpendableUtxoException(super.message);
}
