import 'package:transaction_sync/diagnostics.dart';
import 'dart:async';
import 'dart:math';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bull_sdk.dart' as bull_sdk;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart' show Outpoint;

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
  final Future<bdk.Wallet> Function(WalletModel) _readWallet;

  BdkWalletDatasource({required this._readWallet});

  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.balance,
      () => _readWallet(wallet),
    );
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

  Future<bool> isMine(
    Uint8List scriptBytes, {
    required WalletModel wallet,
    bdk.Wallet? bdkWallet,
  }) async {
    final w = bdkWallet ?? await _readWallet(wallet);
    return w.isMine(script: bdk.Script(rawOutputScript: scriptBytes));
  }

  /// Returns a synchronous `isMine` check bound to a pre-loaded bdk wallet.
  Future<bool Function(Uint8List)> createIsMineChecker({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _readWallet(wallet);
    return (Uint8List scriptBytes) =>
        bdkWallet.isMine(script: bdk.Script(rawOutputScript: scriptBytes));
  }

  /// Returns a synchronous outpoint-ownership check bound to a pre-loaded bdk
  /// wallet.
  ///
  /// Built from `listOutput()`, not `listUnspent()` or `getUtxo()`: those only
  /// know the wallet's *unspent* outputs, so an output we owned and already
  /// spent would answer "not mine". Answering over the full set leaves the
  /// caller no gap to reason about. The set is a snapshot of the local index at
  /// creation time — cheap, no network — so bind it per operation rather than
  /// caching it across syncs.
  Future<bool Function(Outpoint)> createOutpointIsMineChecker({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _readWallet(wallet);
    final owned = <Outpoint>{
      for (final output in bdkWallet.listOutput())
        (txId: output.outpoint.txid.toString(), vout: output.outpoint.vout),
    };
    return owned.contains;
  }

  /// Returns [psbt] with this wallet's BIP32 derivations added to every input
  /// and output it owns, from its local index. Signs nothing: the wallet is
  /// built from the public descriptors.
  ///
  /// A signer only signs inputs it can derive, and learns the path either from
  /// the PSBT or from its own view of the chain. The package's signing wallet
  /// has no view of the chain, so a PSBT must carry the paths — and the input a
  /// payjoin receiver contributes arrives with a witness UTXO and nothing
  /// else. bdk's `sign` fills the paths in for every input whose outpoint the
  /// wallet knows before it looks for keys; with no keys, that is all it does.
  Future<String> addOwnDerivations({
    required String psbt,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _readWallet(wallet);
    final parsed = bdk.Psbt(psbtBase64: psbt);
    bdkWallet.sign(psbt: parsed, signOptions: _annotateOptions);
    return parsed.serialize();
  }

  /// Trusts the witness UTXO a payjoin input carries, and finalizes nothing:
  /// annotation must leave the PSBT for the signer exactly as it found it,
  /// paths aside.
  static final _annotateOptions = bdk.SignOptions(
    trustWitnessUtxo: true,
    assumeHeight: null,
    allowAllSighashes: false,
    tryFinalize: false,
    signWithTapInternalKey: false,
    allowGrinding: true,
  );

  Future<bool> areAddressesMine(
    List<String> addresses, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _readWallet(wallet);
    final network = wallet.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;
    for (final address in addresses) {
      final bdkAddress = bdk.Address(address: address, network: network);
      if (!bdkWallet.isMine(script: bdkAddress.scriptPubkey())) return false;
    }
    return true;
  }

  Future<String> buildPsbt({
    required List<BitcoinTransactionRecipientModel> recipients,
    required NetworkFee networkFee,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxoModel>? selected,
    bool selectedOnly = false,
    bool replaceByFee = true,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.sendBuild,
      () => _readWallet(wallet),
    );

    final network = wallet.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;
    final recipientScripts = [
      for (final recipient in recipients)
        bdk.Address(
          address: recipient.address,
          network: network,
        ).scriptPubkey(),
    ];

    var txBuilder = bdk.TxBuilder();
    for (var index = 0; index < recipients.length; index++) {
      final recipient = recipients[index];
      final script = recipientScripts[index];
      final amountSat = recipient.amountSat;
      if (amountSat == null) {
        txBuilder = txBuilder.drainWallet().drainTo(script: script);
      } else {
        txBuilder = txBuilder.addRecipient(
          script: script,
          amount: bdk.Amount.fromSat(satoshi: amountSat),
        );
      }
    }

    if (selectedOnly && (selected == null || selected.isEmpty)) {
      throw NoSpendableUtxoException(
        'Selected-only transaction requires at least one input',
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
      // TxBuilder is immutable; retain the returned builder so the selected
      // inputs are applied.
      txBuilder = txBuilder.addUtxos(outpoints: selectableOutPoints);
      txBuilder = txBuilder.manuallySelectedOnly();
    }

    // bdk_dart always has RBF (nSequence = 0xFFFFFFFD) enabled by default,
    // so we set the sequence to 0xFFFFFFFE if replaceByFee is explicitly set to false to disable RBF.
    // Same immutable-builder pitfall as addUtxos above — must reassign.
    if (!replaceByFee) {
      txBuilder = txBuilder.setExactSequence(nsequence: 0xFFFFFFFE);
    }

    switch (networkFee) {
      case AbsoluteFee(:final sats):
        txBuilder = txBuilder.feeAbsolute(
          feeAmount: bdk.Amount.fromSat(satoshi: sats),
        );
      case RelativeFee(:final satPerKwu):
        // sat/kwu is BDK's native u64 unit, so this is a zero-rounding
        // pass-through. Using fromSatPerVb would force an int sat/vByte
        // and silently drop fractional rates (the bug fixed in #2133).
        txBuilder = txBuilder.feeRate(
          feeRate: bdk.FeeRate.fromSatPerKwu(satKwu: satPerKwu),
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
      // Check if there are unspents that are not in the unspendable set so a
      // transaction can be built. Compare by (txId, vout) value, NOT by
      // bdk.OutPoint identity: OutPoint/Txid are opaque Rust handles with no
      // `==` override, so a freshly-built OutPoint never equals listUnspent's.
      // Set.contains on the objects would always miss, leaving the all-frozen
      // case undetected (BDK would then fail with "insufficient funds" instead
      // of NoSpendableUtxoException).
      final unspents = bdkWallet.listUnspent();
      final unspendableKeys = unspendable!
          .map((o) => '${o.txId}:${o.vout}')
          .toSet();
      final spendableUtxos = unspents.where((utxo) {
        final key = '${utxo.outpoint.txid}:${utxo.outpoint.vout}';
        return !unspendableKeys.contains(key);
      }).toList();

      if (spendableUtxos.isEmpty) {
        throw NoSpendableUtxoException('All unspents are unspendable');
      }

      txBuilder = txBuilder.unspendable(unspendable: unspendableOutPoints);
    }

    // Finish the transaction building process
    final bdk.Psbt psbt;
    try {
      psbt = txBuilder.finish(wallet: bdkWallet);
    } on bdk.InsufficientFundsCreateTxException catch (e) {
      // Mapped here so callers don't depend on a BDK type.
      throw InsufficientFundsException(e.toString());
    } on bdk.CoinSelectionCreateTxException catch (e) {
      // The same situation reported through a different variant: BDK raises
      // this one when the selection can't cover the outputs plus the fee,
      // which is what hand-picked coins hit.
      throw InsufficientFundsException(e.errorMessage);
    } on bdk.OutputBelowDustLimitCreateTxException catch (e) {
      throw InsufficientFundsException(e.toString());
    }

    final remainder = recipients
        .where((recipient) => recipient.amountSat == null)
        .firstOrNull;
    if (remainder != null) {
      final remainderIndex = recipients.indexOf(remainder);
      final transaction = psbt.extractTx();
      final remainderAmount = _remainderAmountForRecipient(
        remainderIndex: remainderIndex,
        recipients: recipients,
        recipientScripts: recipientScripts,
        outputs: transaction.output(),
      );
      transaction.dispose();
      if (remainderAmount <= 0) {
        throw InsufficientFundsException(
          'Remaining balance is below the destination dust limit',
        );
      }
    }

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
    final targetScript = bdk.Address(
      address: address,
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    ).scriptPubkey();
    final outputs = tx.output();
    int totalAmount = 0;
    for (final output in outputs) {
      if (listEquals(output.scriptPubkey.toBytes(), targetScript.toBytes())) {
        totalAmount += output.value.toSat();
      }
    }
    tx.dispose();
    return totalAmount;
  }

  Future<List<int>> getRecipientAmounts(
    String psbtString,
    List<BitcoinTransactionRecipientModel> recipients, {
    required bool isTestnet,
  }) async {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final recipientScripts = [
      for (final recipient in recipients)
        bdk.Address(
          address: recipient.address,
          network: network,
        ).scriptPubkey(),
    ];
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final tx = psbt.extractTx();
    final outputs = tx.output();
    final amounts = <int>[];
    for (var index = 0; index < recipients.length; index++) {
      final fixedAmount = recipients[index].amountSat;
      if (fixedAmount != null) {
        amounts.add(fixedAmount);
        continue;
      }

      amounts.add(
        _remainderAmountForRecipient(
          remainderIndex: index,
          recipients: recipients,
          recipientScripts: recipientScripts,
          outputs: outputs,
        ),
      );
    }
    tx.dispose();
    return amounts;
  }

  int _remainderAmountForRecipient({
    required int remainderIndex,
    required List<BitcoinTransactionRecipientModel> recipients,
    required List<bdk.Script> recipientScripts,
    required List<bdk.TxOut> outputs,
  }) {
    final targetScript = recipientScripts[remainderIndex].toBytes();
    final totalSentToScript = outputs.fold(
      0,
      (sum, output) => listEquals(output.scriptPubkey.toBytes(), targetScript)
          ? sum + output.value.toSat()
          : sum,
    );
    var fixedToSameScript = 0;
    for (var index = 0; index < recipients.length; index++) {
      final fixedAmount = recipients[index].amountSat;
      if (fixedAmount != null &&
          listEquals(recipientScripts[index].toBytes(), targetScript)) {
        fixedToSameScript += fixedAmount;
      }
    }
    return totalSentToScript - fixedToSameScript;
  }

  // 25000 - 988

  Future<List<WalletUtxoModel>> getUtxos({required WalletModel wallet}) async {
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.utxos,
      () => _readWallet(wallet),
    );
    final unspent = bdkWallet.listUnspent();
    // Chain tip read once from the already-synced wallet (no extra network
    // calls); reused for every utxo's confirmation count.
    final tip = bdkWallet.latestCheckpoint().height;
    final utxos = await Future.wait(
      unspent.map((unspent) async {
        final address =
            await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
              unspent.txout.scriptPubkey.toBytes(),
              isTestnet: wallet.isTestnet,
            );
        // Confirmation count from the utxo's chain position (mirrors the
        // handling in getTransactions); unconfirmed utxos report 0.
        final chainPosition = unspent.chainPosition;
        final confirmedHeight = chainPosition is bdk.ConfirmedChainPosition
            ? chainPosition.confirmationBlockTime.blockId.height
            : null;
        final confirmations = confirmationsFromTip(
          tip: tip,
          height: confirmedHeight,
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
          confirmations: confirmations,
        );
      }),
    );
    return utxos;
  }

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.transactions,
      () => _readWallet(wallet),
    );

    // Both mapping passes reuse these strings after releasing their owned temporary native handles.
    final transactions = bdkWallet.transactions().map((tx) {
      return (tx, _consumeTxid(tx.transaction.computeTxid()));
    }).toList();

    final allTransactionOutputs = await _getAllOutputsOfTransactions(
      transactions,
      wallet: wallet,
      bdkWallet: bdkWallet,
    );

    // Map the transactions to WalletTransactionModel
    final List<WalletTransactionModel?> walletTxs = await Future.wait(
      transactions.map((entry) async {
        final (tx, txId) = entry;
        final outputs = tx.transaction.output();

        if (toAddress != null && toAddress.isNotEmpty) {
          // Filter transactions by address by returning null for non-matching transactions
          // and then removing null values from the list with whereType at the end of the method
          final matches = (await Future.wait(
            outputs.map((output) async {
              final address =
                  await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                    output.scriptPubkey.toBytes(),
                    isTestnet: wallet.isTestnet,
                  );
              if (address == null) return false;
              return address == toAddress;
            }),
          )).any((matches) => matches);

          if (!matches) return null;
        }

        // Map inputs and outputs to their respective models
        final inputModels = tx.transaction.input().asMap().entries.map((entry) {
          final input = entry.value;
          final vin = entry.key;
          final previousOutput = input.previousOutput;
          final previousTxId = _consumeTxid(previousOutput.txid);
          final output = allTransactionOutputs.firstWhereOrNull(
            (output) =>
                output.txId == previousTxId &&
                output.vout == previousOutput.vout,
          );

          return TransactionInputModel.bitcoin(
            txId: txId,
            vin: vin,
            isOwn: output?.isOwn ?? false,
            scriptSig: input.scriptSig.toBytes(),
            previousTxId: previousTxId,
            previousTxVout: previousOutput.vout,
          );
        }).toList();
        final outputModels = allTransactionOutputs
            .where((output) => output.txId == txId)
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
        final netAmountSat = _netAmountSatOf(
          isToSelf: isToSelf,
          isIncoming: isIncoming,
          outputs: outputModels,
          sent: sent,
          received: received,
          fee: fee,
        );

        return WalletTransactionModel(
          txId: txId,
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

  // This can return -1 if no address has been revealed yet.
  // This should be handled accordingly by the caller.
  Future<int> getLastRevealedAddressIndex({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.addressList,
      () => _readWallet(wallet),
    );
    return bdkWallet.nextDerivationIndex(
          keychain: isChange
              ? bdk.KeychainKind.internal
              : bdk.KeychainKind.external_,
        ) -
        1;
  }

  Future<String> getAddressByIndex(
    int index, {
    required WalletModel wallet,
    isChange = false,
  }) async {
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.addressList,
      () => _readWallet(wallet),
    );
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
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.addressList,
      () => _readWallet(wallet),
    );
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
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.addressList,
      () => _readWallet(wallet),
    );
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

  /// The amount to show for a transaction, from this wallet's point of view.
  static int _netAmountSatOf({
    required bool isToSelf,
    required bool isIncoming,
    required List<BitcoinTransactionOutputModel> outputs,
    required int sent,
    required int received,
    required int fee,
  }) {
    if (isToSelf) {
      // `sent` is the whole utxo we spent, not what we paid: coin selection
      // spends whole utxos and hands the rest back as change.
      final toDestination = outputs
          .where((output) => !output.isChange)
          .fold(0, (sum, output) => sum + (output.value?.toInt() ?? 0));
      // Nothing paid out — a consolidation. The fee is the only balance change.
      return toDestination > 0 ? toDestination : fee;
    }

    // The sender paid the fee, so it never left this balance.
    if (isIncoming) return received - sent;

    // We paid the fee, so take it off to leave what reached the recipient.
    return sent - received - fee;
  }

  /// Consumes only a freshly acquired txid, never a shared wallet handle.
  static String _consumeTxid(bdk.Txid txid) {
    try {
      return txid.toString();
    } finally {
      txid.dispose();
    }
  }

  Future<List<BitcoinTransactionOutputModel>> _getAllOutputsOfTransactions(
    List<(bdk.CanonicalTx, String)> transactions, {
    required WalletModel wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    // Our own change outputs, by outpoint. In a send-to-self every output is
    // ours, so only the keychain separates the recipient from the change.
    // `listOutput()` covers spent outputs too, and hits no network.
    final changeOutpoints = <Outpoint>{
      for (final output in bdkWallet.listOutput())
        if (output.keychain == bdk.KeychainKind.internal)
          (
            txId: _consumeTxid(output.outpoint.txid),
            vout: output.outpoint.vout,
          ),
    };

    final listOfOutputs = await Future.wait(
      transactions.map((entry) async {
        final (tx, txId) = entry;
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
              txId: txId,
              vout: vout,
              isOwn: await isMine(
                scriptPubkeyBytes,
                wallet: wallet,
                bdkWallet: bdkWallet,
              ),
              value: BigInt.from(output.value.toSat()),
              scriptPubkey: scriptPubkeyBytes,
              address: address,
              isChange: changeOutpoints.contains((txId: txId, vout: vout)),
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
    required RelativeFee feeRate,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.sendBuild,
      () => _readWallet(wallet),
    );
    // BumpFeeTxBuilder is rate-only by BDK design (BIP-125 requires a
    // higher rate, not absolute, to replace). We hit it with sat/kwu so
    // sub-1 sat/vByte bumps survive without precision loss.
    final tx = bdk.BumpFeeTxBuilder(
      txid: bdk.Txid.fromString(hex: txid),
      feeRate: bdk.FeeRate.fromSatPerKwu(satKwu: feeRate.satPerKwu),
    );
    final psbt = tx.finish(wallet: bdkWallet);
    return psbt.serialize();
  }

  /// Guard for GHSA-6jp4-8v48-cc5v: the Electrum server is trusted for
  /// mempool transactions, so a malicious one can swallow a broadcast and
  /// plant a conflicting copy with redirected outputs and forged signatures.
  /// SIGHASH_ALL signatures commit to the outputs, so verifying the
  /// wallet-owned inputs' signatures against the transaction as stored
  /// authenticates the outputs before a replacement is built from them.
  /// Inputs whose prevout is unknown to the wallet (e.g. a payjoin
  /// counterparty's) cannot be judged and are skipped; at least one owned
  /// input must verify. The SDK verifier requires every signature to be
  /// ECDSA with SIGHASH_ALL — the only flag this wallet produces — so a
  /// signature that doesn't commit to the outputs never passes. Sound for
  /// legacy and segwit v0 only: taproot (BIP341) signatures commit to every
  /// prevout, so the skip-unresolvable-inputs loop below must be revisited
  /// before a bip86 script type ships.
  ///
  /// A transaction (or prevout) missing from the store is
  /// [TransactionSignatureStatus.unverifiable], not proof of manipulation —
  /// callers must still refuse to build on it. The SDK's Malformed variant
  /// is never an attacker signal: it only covers caller-side errors
  /// (undeserializable bytes, empty input list, out-of-bounds index), all
  /// impossible here since the bytes and indexes come from the stored
  /// transaction itself; a bad or misencoded signature reports as
  /// InvalidSignatures.
  Future<TransactionSignatureStatus> verifyTransactionInputSignatures({
    required String txid,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await _readWallet(wallet);
    final canonicalTx = bdkWallet.getTx(txid: bdk.Txid.fromString(hex: txid));
    if (canonicalTx == null) return TransactionSignatureStatus.unverifiable;
    final tx = canonicalTx.transaction;
    final inputs = tx.input();
    final inputsToVerify = <bull_sdk.TxInputToVerify>[];
    for (var index = 0; index < inputs.length; index++) {
      final outpoint = inputs[index].previousOutput;
      final parentTx = bdkWallet.getTx(txid: outpoint.txid);
      if (parentTx == null) continue;
      final parentOutputs = parentTx.transaction.output();
      if (outpoint.vout >= parentOutputs.length) {
        return TransactionSignatureStatus.unverifiable;
      }
      final prevout = parentOutputs[outpoint.vout];
      if (!bdkWallet.isMine(script: prevout.scriptPubkey)) continue;
      inputsToVerify.add(
        bull_sdk.TxInputToVerify(
          inputIndex: index,
          prevoutScriptPubkey: prevout.scriptPubkey.toBytes(),
          prevoutValueSat: BigInt.from(prevout.value.toSat()),
        ),
      );
    }
    if (inputsToVerify.isEmpty) return TransactionSignatureStatus.unverifiable;
    final verification = await bull_sdk.verifyTxInputSignatures(
      txBytes: tx.serialize(),
      inputs: inputsToVerify,
    );
    return switch (verification) {
      bull_sdk.TxSignatureVerification_Valid() =>
        TransactionSignatureStatus.valid,
      bull_sdk.TxSignatureVerification_InvalidSignatures() =>
        TransactionSignatureStatus.invalid,
      bull_sdk.TxSignatureVerification_Malformed() =>
        TransactionSignatureStatus.unverifiable,
    };
  }

  Future<({BigInt satoshis, int transactions})> dryScan({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required ElectrumConnection electrumServer,
  }) {
    final rootIsolateToken = ServicesBinding.rootIsolateToken;
    if (rootIsolateToken == null) {
      throw StateError('A dry scan must start from the root isolate');
    }
    return compute(
      _performDryScan,
      _DryScanParams(
        externalDescriptor: externalDescriptor,
        internalDescriptor: internalDescriptor,
        isTestnet: isTestnet,
        electrumUrl: electrumServer.url,
        electrumSocks5: electrumServer.socks5,
        electrumStopGap: electrumServer.stopGap,
        electrumTimeout: electrumServer.effectiveTimeout,
        electrumRetry: electrumServer.retry,
        electrumValidateDomain: electrumServer.validateDomain,
        rootIsolateToken: rootIsolateToken,
      ),
    );
  }
}

class FailedToSignPsbtException extends BullException {
  FailedToSignPsbtException(super.message);
}

class UnsupportedBdkNetworkException extends BullException {
  UnsupportedBdkNetworkException(super.message);
}

/// Confirmation count for an output confirmed at [height], given the current
/// chain [tip]. A `null` height (unconfirmed) returns 0; the result is clamped
/// to 0 to guard a reorg / mid-sync window where `tip < height` (D2).
int confirmationsFromTip({required int tip, required int? height}) {
  if (height == null) return 0;
  return max(0, tip - height + 1);
}

class _DryScanParams {
  final String externalDescriptor;
  final String internalDescriptor;
  final bool isTestnet;
  final String electrumUrl;
  final String? electrumSocks5;
  final int electrumStopGap;
  final int electrumTimeout;
  final int electrumRetry;
  final bool electrumValidateDomain;
  final RootIsolateToken rootIsolateToken;

  _DryScanParams({
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.isTestnet,
    required this.electrumUrl,
    required this.electrumSocks5,
    required this.electrumStopGap,
    required this.electrumTimeout,
    required this.electrumRetry,
    required this.electrumValidateDomain,
    required this.rootIsolateToken,
  });
}

Future<({BigInt satoshis, int transactions})> _performDryScan(
  _DryScanParams params,
) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

  final bdkNetwork = params.isTestnet
      ? bdk.Network.testnet
      : bdk.Network.bitcoin;
  final bdkNetworkKind = params.isTestnet
      ? bdk.NetworkKind.test
      : bdk.NetworkKind.main;

  bdk.Descriptor? external;
  bdk.Descriptor? internal;
  try {
    external = bdk.Descriptor(
      descriptor: params.externalDescriptor,
      networkKind: bdkNetworkKind,
    );
    internal = bdk.Descriptor(
      descriptor: params.internalDescriptor,
      networkKind: bdkNetworkKind,
    );
    final persister = bdk.Persister.newInMemory();
    try {
      final wallet = bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: bdkNetwork,
        persister: persister,
        lookahead: 0,
      );
      try {
        final blockchain = _createElectrumClient(
          url: params.electrumUrl,
          socks5: params.electrumSocks5,
          timeout: params.electrumTimeout,
          retry: params.electrumRetry,
          validateDomain: params.electrumValidateDomain,
        );
        try {
          final requestBuilder = wallet.startFullScan();
          try {
            final request = requestBuilder.build();
            try {
              final update = blockchain.fullScan(
                request: request,
                stopGap: params.electrumStopGap,
                batchSize: _batchSizeFor(params.electrumStopGap),
                fetchPrevTxouts: false,
              );
              try {
                wallet.applyUpdate(update: update);
                final balance = wallet.balance();
                return (
                  satoshis: BigInt.from(balance.confirmed.toSat()),
                  transactions: wallet.transactions().length,
                );
              } finally {
                update.dispose();
              }
            } finally {
              request.dispose();
            }
          } finally {
            requestBuilder.dispose();
          }
        } finally {
          blockchain.dispose();
        }
      } finally {
        wallet.dispose();
      }
    } finally {
      persister.dispose();
    }
  } finally {
    internal?.dispose();
    external?.dispose();
  }
}

int _batchSizeFor(int stopGap) => (stopGap ~/ 4).clamp(50, 1000);

/// Creates a [bdk.ElectrumClient], retrying once on the rustls CryptoProvider
/// install race across concurrent isolates (full scan, dry scan, sync).
/// electrum-client's install_default check+install is not atomic, so two
/// isolates can both see "not installed" and the loser fails. On retry the
/// provider is already installed and the check short-circuits.
bdk.ElectrumClient _createElectrumClient({
  required String url,
  required String? socks5,
  required int timeout,
  required int retry,
  required bool validateDomain,
}) {
  bdk.ElectrumClient build() => bdk.ElectrumClient(
    url: url,
    socks5: socks5?.isNotEmpty == true ? socks5 : null,
    timeout: timeout.clamp(0, 255),
    retry: retry.clamp(0, 255),
    validateDomain: validateDomain,
  );
  try {
    return build();
  } on bdk.CouldNotCreateConnectionElectrumException catch (e) {
    if (e.errorMessage.contains('Failed to install CryptoProvider')) {
      return build();
    }
    rethrow;
  }
}
