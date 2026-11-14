import 'package:sync/diagnostics.dart';
import 'dart:async';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bull_sdk.dart' as bull_sdk;
import 'package:flutter/foundation.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:sync/sync.dart' as sync;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';

extension NetworkX on Network {
  bdk.Network get bdkNetwork {
    switch (this) {
      case Network.bitcoinMainnet:
        return bdk.Network.bitcoin;
      case Network.bitcoinTestnet:
        return bdk.Network.testnet;
      case Network.bitcoinRegtest:
        return bdk.Network.regtest;
      default:
        throw UnsupportedBdkNetworkException('$name is not supported by BDK');
    }
  }
}

extension BdkNetworkX on bdk.Network {
  Network get network => switch (this) {
    bdk.Network.bitcoin => Network.bitcoinMainnet,
    bdk.Network.testnet => Network.bitcoinTestnet,
    bdk.Network.regtest => Network.bitcoinRegtest,
    _ => throw const UnsupportedNetworkException(),
  };
}

class BdkWalletDatasource {
  final Future<bdk.Wallet> Function(WalletModel) _readWallet;

  BdkWalletDatasource({required this._readWallet});

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

  Future<String> buildPsbt({
    required List<BitcoinTransactionRecipientModel> recipients,
    required NetworkFee networkFee,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxoModel>? selected,
    bool selectedOnly = false,
    bool replaceByFee = true,
    required WalletModel wallet,
  }) async {
    // SDK validation is exact for the captured concrete wallet network.
    // Testnet/regtest Base58 is ambiguous, so new regtest sends require bcrt1.
    if (wallet.network == Network.bitcoinRegtest &&
        recipients.any(
          (recipient) => !recipient.address.toLowerCase().startsWith('bcrt1'),
        )) {
      throw const UnsupportedNetworkException();
    }
    final bdkWallet = await LeaseDiagnostics.from(
      LeaseSource.sendBuild,
      () => _readWallet(wallet),
    );

    final network = wallet.network.bdkNetwork;
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
    required Network network,
  }) async {
    final psbt = bdk.Psbt(psbtBase64: psbtString);
    final tx = psbt.extractTx();
    final targetScript = bdk.Address(
      address: address,
      network: network.bdkNetwork,
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
    required Network network,
  }) async {
    final bdkNetwork = network.bdkNetwork;
    final recipientScripts = [
      for (final recipient in recipients)
        bdk.Address(
          address: recipient.address,
          network: bdkNetwork,
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

  // This can return -1 if no address has been revealed yet.
  // This should be handled accordingly by the caller.
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

  /// A full scan of a wallet not yet imported, in memory, through sync.
  /// Throws [PrescanFailedException] for the server fallback to try the next.
  Future<({BigInt satoshis, int transactions})> dryScan({
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
    required ElectrumConnection electrumServer,
  }) async {
    final scanned = await sync.prescanBitcoinWallet(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: network.bitcoin,
      connection: sync.WalletConnection(
        url: electrumServer.url,
        socks5: electrumServer.socks5,
        timeout: Duration(seconds: electrumServer.effectiveTimeout),
        retry: electrumServer.retry,
        stopGap: electrumServer.stopGap,
        validateDomain: electrumServer.validateDomain,
      ),
    );
    return switch (scanned) {
      Ok(:final value) => (
        satoshis: value.confirmedSat,
        transactions: value.transactions,
      ),
      Err(:final failure) => throw PrescanFailedException(failure),
    };
  }
}

/// The prescan failed on this server; the fallback may try the next.
class PrescanFailedException implements Exception {
  final sync.SyncFailure failure;
  const PrescanFailedException(this.failure);

  @override
  String toString() => 'PrescanFailedException(${failure.logCode})';
}

class FailedToSignPsbtException extends BullException {
  FailedToSignPsbtException(super.message);
}

class UnsupportedBdkNetworkException extends BullException {
  UnsupportedBdkNetworkException(super.message);
}
