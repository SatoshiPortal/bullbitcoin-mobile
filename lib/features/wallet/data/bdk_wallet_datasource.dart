import 'sync_wallet_values_datasource.dart';

import 'dart:math';

import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_wallet_policy_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_psbt_review_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_policy_maturity_model.dart';

import 'bitcoin_policy_codec.dart';
import 'bitcoin_descriptor_codec.dart';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;

/// [walletId]'s sync handle on its current generation.
typedef SpendWallet = Future<sync.Wallet> Function(String walletId);

/// Bitcoin spends through `wallet.tx`, and the PSBT facts the app reads
/// without a wallet. No native handle is held here.
class BdkWalletDatasource {
  final SpendWallet _wallet;
  final SyncWalletValuesDatasource _values;

  BdkWalletDatasource({
    required this._wallet,
    required SyncWalletValuesDatasource walletValuesDatasource,
  }) : _values = walletValuesDatasource;

  static T _value<T>(Result<T, sync.SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  /// Returns [psbt] with this wallet's BIP32 derivations added to every input
  /// and output it owns, from its local index. Signs nothing: sync builds the
  /// wallet from the public descriptors.
  ///
  /// A signer only signs inputs it can derive, and learns the path either from
  /// the PSBT or from its own view of the chain. The package's signing wallet
  /// has no view of the chain, so a PSBT must carry the paths — and the input a
  /// payjoin receiver contributes arrives with a witness UTXO and nothing
  /// else.
  Future<String> addOwnDerivations({
    required String psbt,
    required WalletModel wallet,
  }) async => _value(await (await _wallet(wallet.id)).tx.annotate(psbt));

  /// One build by the writer, which also excludes the freezes and the
  /// reservations of other sessions and refuses a selected protected coin.
  Future<Result<sync.UnsignedSpend, sync.SyncFailure>> buildPsbt({
    required List<BitcoinTransactionRecipientModel> recipients,
    required NetworkFee networkFee,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxoModel>? selected,
    bool selectedOnly = false,
    bool replaceByFee = true,
    BitcoinPolicyPath? policyPath,
    ({
      List<WalletDescriptorKeyModel> external,
      List<WalletDescriptorKeyModel> internal,
    })?
    requiredDescriptorKeys,
    required WalletModel wallet,
  }) async {
    final sync.BitcoinSpendRequest request;
    try {
      request = sync.BitcoinSpendRequest(
        recipients: [
          for (final recipient in recipients)
            sync.SpendRecipient(
              recipient.address,
              amountSat: recipient.amountSat,
            ),
        ],
        fee: switch (networkFee) {
          AbsoluteFee(:final sats) => sync.SpendAbsoluteFee(sats),
          RelativeFee(:final satPerKwu) => sync.SpendFeeRate(satPerKwu),
        },
        selected: selected == null
            ? null
            : [for (final utxo in selected) (txId: utxo.txId, vout: utxo.vout)],
        selectedOnly: selectedOnly,
        replaceable: replaceByFee,
        policy: policyPath == null
            ? null
            : sync.BitcoinSpendPolicy(
                external: policyPath.external,
                internal: policyPath.internal,
                requiresRelativeTimelock: policyPath.requiresRelativeTimelock,
                eligibleExternal: _outpoints(
                  policyPath.eligibleExternalOutpoints,
                ),
                eligibleInternal: _outpoints(
                  policyPath.eligibleInternalOutpoints,
                ),
                requiredKeys: requiredDescriptorKeys == null
                    ? null
                    : (
                        external: requiredDescriptorKeys.external
                            .map((key) => key.policyKey)
                            .toList(),
                        internal: requiredDescriptorKeys.internal
                            .map((key) => key.policyKey)
                            .toList(),
                      ),
              ),
        exclude: {...?unspendable},
      );
    } on ArgumentError {
      // A request the builder cannot express: no recipient, two remainders,
      // a zero amount or fee rate.
      return const Err(sync.SyncSpendRefusedFailure());
    }
    return (await _wallet(wallet.id)).tx.build(request);
  }

  Future<int> decodeTxSize(
    String psbtString, {
    required PublicBdkWalletModel wallet,
  }) async => policyValue(
    _codec.transactionVsize(psbtString, wallet: wallet.policyDescriptor),
  );

  Future<int> getFeeAmount(String psbtString) async =>
      switch (sync.bitcoinPsbtFee(psbtString)) {
        Ok(:final value) => value,
        Err() => throw const FormatException('PSBT fee unknown'),
      };

  static const _codec = sync.BitcoinPolicyCodec();

  static Set<({String txId, int vout})>? _outpoints(Set<String>? values) =>
      values == null
      ? null
      : {
          for (final value in values)
            (
              txId: value.substring(0, value.lastIndexOf(':')),
              vout: int.parse(value.substring(value.lastIndexOf(':') + 1)),
            ),
        };

  BdkTwoPathDescriptor parsePublicTwoPathDescriptor({
    required String descriptor,
    required Network network,
  }) => BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: descriptor,
    network: network,
  );

  BitcoinWalletPolicyModel analyzePolicy({
    required PublicBdkWalletModel wallet,
    List<WalletDescriptorKeyModel> descriptorKeys = const [],
  }) => policyValue(
    _codec.analyzePolicy(
      wallet: wallet.policyDescriptor,
      descriptorKeys: descriptorKeys.map((key) => key.policyKey).toList(),
    ),
  );

  Future<BitcoinPsbtReviewModel> inspectPsbt(
    String psbt, {
    required PublicBdkWalletModel wallet,
    required Set<String> walletFingerprints,
  }) async => policyValue(
    _codec.inspectPsbt(
      psbt,
      wallet: wallet.policyDescriptor,
      walletFingerprints: walletFingerprints,
      ownership: await _values.getOwnership(wallet: wallet),
    ),
  );

  Future<({String psbt, bool signWithTapInternalKey})> preparePsbtForSigning(
    String psbt, {
    PublicBdkWalletModel? foreignInputWallet,
  }) async => policyValue(
    _codec.prepareSigning(
      psbt,
      foreignInputWallet: foreignInputWallet == null
          ? null
          : await _values.getOwnership(wallet: foreignInputWallet),
    ),
  );

  Future<void> validateWalletPsbtInputs(
    String psbt, {
    required PublicBdkWalletModel wallet,
    Set<String> frozenOutpoints = const {},
    String? replacingTxid,
    bool allowSpentWalletInputs = false,
  }) async => policyValue(
    _codec.validateInputs(
      psbt,
      ownership: await _values.getOwnership(wallet: wallet),
      frozenOutpoints: frozenOutpoints,
      replacingTxid: replacingTxid,
      allowSpentWalletInputs: allowSpentWalletInputs,
    ),
  );

  Future<BitcoinPolicyMaturityModel> getPolicyMaturity({
    required PublicBdkWalletModel wallet,
    ElectrumConnection? electrumServer,
    required bool includeTimeBasedLocks,
    bool includeRelativeTimeLocks = true,
  }) async {
    final index = await _values.getOwnership(wallet: wallet);
    final unspent = index.outputs.entries.where(
      (entry) => !entry.value.isSpent,
    );
    var tipHeight = index.tipHeight;
    int? medianTimePast;
    final confirmationMedianTimes = <int, int>{};
    if (electrumServer != null) {
      final chain = _value(
        await sync.bitcoinPolicyChainState(
          _connection(electrumServer),
          includeMedianTimePast: includeTimeBasedLocks,
          referenceHeights: includeTimeBasedLocks && includeRelativeTimeLocks
              ? {
                  for (final entry in unspent)
                    if (entry.value.confirmationHeight case final height?)
                      max(0, height - 1),
                }
              : const {},
        ),
      );
      tipHeight = chain.tipHeight;
      medianTimePast = chain.medianTimePast;
      confirmationMedianTimes.addAll(chain.referenceMedianTimes);
    }
    return BitcoinPolicyMaturityModel(
      tipHeight: tipHeight,
      medianTimePast: medianTimePast,
      utxos: [
        for (final entry in unspent)
          BitcoinPolicyUtxoMaturityModel(
            outpoint: '${entry.key.txId}:${entry.key.vout}',
            keychain: entry.value.keychain,
            amountSat: entry.value.amountSat,
            confirmations: switch (entry.value.confirmationHeight) {
              final height? => max(0, tipHeight - height + 1),
              null => 0,
            },
            confirmationMedianTimePast:
                switch (entry.value.confirmationHeight) {
                  final height? => confirmationMedianTimes[max(0, height - 1)],
                  null => null,
                },
          ),
      ],
    );
  }

  static sync.WalletConnection _connection(ElectrumConnection connection) =>
      sync.WalletConnection(
        url: connection.url,
        socks5: connection.socks5,
        timeout: Duration(seconds: connection.effectiveTimeout),
        retry: connection.retry,
        stopGap: connection.stopGap,
        validateDomain: connection.validateDomain,
      );

  static sync.BitcoinHashPreimage _preimage(BitcoinPolicyPreimage value) =>
      sync.BitcoinHashPreimage(
        type: switch (value.type) {
          BitcoinHashlockType.sha256 => sync.BitcoinPreimageType.sha256,
          BitcoinHashlockType.hash256 => sync.BitcoinPreimageType.hash256,
          BitcoinHashlockType.ripemd160 => sync.BitcoinPreimageType.ripemd160,
          BitcoinHashlockType.hash160 => sync.BitcoinPreimageType.hash160,
        },
        hash: value.hash,
        preimageHex: value.preimageHex,
      );

  bool validatePolicyPreimage(BitcoinPolicyPreimage preimage) =>
      policyValue(_codec.validatePreimage(_preimage(preimage)));
  String applyPolicyPreimages(
    String psbt,
    List<BitcoinPolicyPreimage> preimages,
  ) => policyValue(
    _codec.applyPreimages(psbt, preimages.map(_preimage).toList()),
  );
  ({String transaction, int txSize}) verifyFinalTransaction({
    required String psbtBase64,
    required String transactionHex,
  }) => policyValue(
    _codec.verifyFinalTransaction(
      psbtBase64: psbtBase64,
      transactionHex: transactionHex,
    ),
  );
  ({String psbt, bool isFinalized}) completePsbtSigning({
    required String originalPsbt,
    required String signedPsbt,
    bool tryFinalize = true,
  }) => policyValue(
    _codec.completeSigning(
      originalPsbt: originalPsbt,
      signedPsbt: signedPsbt,
      tryFinalize: tryFinalize,
    ),
  );
  String combinePsbts({required String first, required String second}) =>
      policyValue(_codec.combinePsbts(first: first, second: second));
  String validateExternalPartialPsbt({
    required String currentPsbtBase64,
    required String signedPsbtBase64,
  }) => policyValue(
    _codec.validateExternalPartialPsbt(
      currentPsbtBase64: currentPsbtBase64,
      signedPsbtBase64: signedPsbtBase64,
    ),
  );
  ({String psbt, bool isFinalized}) finalizePsbt(String psbt) =>
      policyValue(_codec.finalizePsbt(psbt));

  static Uint8List _script(String address, Network network) =>
      switch (sync.bitcoinAddressScript(address, network.bitcoin)) {
        Ok(:final value) => value,
        Err(:final failure) => throw WalletSnapshotException(failure),
      };

  Future<int> getAmountSentToAddress(
    String psbtString,
    String address, {
    required Network network,
  }) async {
    final target = _script(address, network);
    var total = 0;
    for (final output in sync.decodeBitcoinPsbt(psbtString).outputs) {
      if (listEquals(output.scriptPubkey, target)) total += output.valueSat;
    }
    return total;
  }

  Future<List<int>> getRecipientAmounts(
    String psbtString,
    List<BitcoinTransactionRecipientModel> recipients, {
    required Network network,
  }) async {
    final scripts = [
      for (final recipient in recipients) _script(recipient.address, network),
    ];
    final outputs = sync.decodeBitcoinPsbt(psbtString).outputs;
    return [
      for (var index = 0; index < recipients.length; index++)
        recipients[index].amountSat ??
            _remainderAmountForRecipient(
              remainderIndex: index,
              recipients: recipients,
              recipientScripts: scripts,
              outputs: outputs,
            ),
    ];
  }

  int _remainderAmountForRecipient({
    required int remainderIndex,
    required List<BitcoinTransactionRecipientModel> recipients,
    required List<Uint8List> recipientScripts,
    required List<sync.DecodedBitcoinOutput> outputs,
  }) {
    final target = recipientScripts[remainderIndex];
    final totalSentToScript = outputs.fold(
      0,
      (sum, output) =>
          listEquals(output.scriptPubkey, target) ? sum + output.valueSat : sum,
    );
    var fixedToSameScript = 0;
    for (var index = 0; index < recipients.length; index++) {
      final fixedAmount = recipients[index].amountSat;
      if (fixedAmount != null && listEquals(recipientScripts[index], target)) {
        fixedToSameScript += fixedAmount;
      }
    }
    return totalSentToScript - fixedToSameScript;
  }

  /// A BIP125 replacement built by the writer, only on an original whose
  /// own inputs' signatures verify.
  Future<Result<sync.UnsignedSpend, sync.SyncFailure>>
  createUnsignedReplaceByFeePsbt({
    required String txid,
    required RelativeFee feeRate,
    required WalletModel wallet,
  }) async => (await _wallet(wallet.id)).tx.bump(
    sync.BumpFeeRequest(txid: txid, fee: sync.SpendFeeRate(feeRate.satPerKwu)),
  );

  /// Guard for GHSA-6jp4-8v48-cc5v, run by sync on a wallet opened for the
  /// check. A transaction missing from the store is
  /// [TransactionSignatureStatus.unverifiable], not proof of manipulation;
  /// callers must still refuse to build on it.
  Future<TransactionSignatureStatus> verifyTransactionInputSignatures({
    required String txid,
    required WalletModel wallet,
  }) async => switch (_value(
    await (await _wallet(wallet.id)).tx.originalSignatures(txid),
  )) {
    sync.SignatureCheck.valid => TransactionSignatureStatus.valid,
    sync.SignatureCheck.invalid => TransactionSignatureStatus.invalid,
    sync.SignatureCheck.unverifiable => TransactionSignatureStatus.unverifiable,
  };

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
