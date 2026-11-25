import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';

import '../../ark.dart';
import 'ark_native_session.dart';

/// Revalidates committed authorization and exact bytes without opening a wallet.
/// The host verifier must compare the full final PSBT transaction including
/// witnesses with raw bytes; its facts alone are not signature-validity proof.
final class ArkSavedClaim {
  final String raw;
  final ArkClaimRecovery summary;
  final List<String> outpoints;
  ArkSavedClaim._(this.raw, this.summary, this.outpoints);

  static String digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  /// Reserve inputs are authorized by the quote, never by native output.
  /// Only VTXOs count against the exit's claim allowance.
  static Set<String> expectedInputs(
    ArkQuote quote,
    Set<String> actual,
    Set<String> skipped,
  ) {
    if (quote.reserveOutpoints.isEmpty) return actual;
    final reserve = quote.reserveOutpoints.toSet();
    if (quote.kind != ArkOperationKind.claim ||
        quote.account.network != BitcoinNetwork.regtest ||
        skipped.isNotEmpty ||
        actual.length != quote.selectedIds.length ||
        !actual.containsAll(quote.selectedIds) ||
        reserve.length != quote.reserveOutpoints.length ||
        reserve.intersection(actual).isNotEmpty) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    return actual.union(reserve);
  }

  static Map<String, Object?> evidence({
    required ArkQuote quote,
    required String operationId,
    required ArkClaimTransaction claim,
    required ArkClaimRecovery summary,
  }) => {
    'version': 1,
    'account': quote.account.canonical,
    'operationId': operationId,
    'quoteId': quote.id,
    'source': quote.chainSource.toString(),
    'configGeneration': quote.configGeneration,
    'raw': claim.rawTransaction,
    'signedPsbt': claim.signedPsbt,
    'rawDigest': digest(claim.rawTransaction),
    'psbtDigest': digest(claim.signedPsbt),
    'txid': summary.txid,
    'destination': summary.destination,
    'fee': summary.fee.toString(),
    'net': summary.net.toString(),
    'inputAmounts': {
      for (final entry in claim.inputAmounts.entries)
        if (claim.actualIds.contains(entry.key) ||
            quote.reserveOutpoints.contains(entry.key))
          entry.key: entry.value,
    },
  };

  static Future<ArkSavedClaim> inspect({
    required ArkAccountId account,
    required ArkAccountConfig config,
    required ArkQuote quote,
    required ArkOperation operation,
    required Map<String, Object?> evidence,
    required ArkTransactionVerifierPort verifier,
  }) async {
    Never refuse() => throw const ArkBoundaryException(ArkValidationFailure());
    final raw = evidence['raw'];
    final psbt = evidence['signedPsbt'];
    final txid = operation.nativeReference;
    final actual = operation.actualIds.toSet();
    final skipped = operation.skippedIds.toSet();
    final expected = expectedInputs(quote, actual, skipped);
    final selected = quote.selectedIds.toSet();
    final inputs = evidence['inputAmounts'];
    final maximum = quote.maxClaimFee;
    final destination = quote.destination;
    if (config.id != account ||
        quote.account != account ||
        quote.kind != ArkOperationKind.claim ||
        operation.kind != quote.kind ||
        operation.configGeneration != quote.configGeneration ||
        quote.configGeneration != 1 ||
        operation.chainSource != quote.chainSource ||
        (operation.chainSource != config.primaryEsploraUrl &&
            operation.chainSource != config.fallbackEsploraUrl) ||
        evidence['version'] != 1 ||
        evidence['account'] != account.canonical ||
        evidence['operationId'] != operation.id ||
        evidence['quoteId'] != quote.id ||
        evidence['source'] != operation.chainSource.toString() ||
        evidence['configGeneration'] != operation.configGeneration ||
        raw is! String ||
        raw.isEmpty ||
        psbt is! String ||
        psbt.isEmpty ||
        evidence['rawDigest'] != digest(raw) ||
        evidence['psbtDigest'] != digest(psbt) ||
        txid == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(txid) ||
        evidence['txid'] != txid ||
        actual.isEmpty ||
        actual.length != operation.actualIds.length ||
        skipped.length != operation.skippedIds.length ||
        actual.intersection(skipped).isNotEmpty ||
        selected.length != actual.length + skipped.length ||
        !selected.containsAll(actual.union(skipped)) ||
        inputs is! Map ||
        inputs.length != expected.length ||
        maximum == null ||
        destination == null ||
        destination.isEmpty) {
      refuse();
    }
    final result = await verifier.inspectTransaction(
      transactionHex: raw,
      signedPsbt: psbt,
      network: account.network,
    );
    if (result case Err(:final failure)) {
      throw ArkBoundaryException(failure);
    }
    final facts = (result as Ok<ArkTransactionFacts, ArkWalletFailure>).value;
    final total = facts.inputs.fold<BigInt>(
      BigInt.zero,
      (sum, input) => sum + input.amount.value,
    );
    if (facts.txid != txid ||
        facts.psbtTxid != txid ||
        facts.inputs.length != expected.length ||
        facts.inputs.map((v) => v.outpoint).toSet().length != expected.length ||
        !facts.inputs.every(
          (v) =>
              expected.contains(v.outpoint) &&
              v.finalWitness &&
              inputs[v.outpoint] == v.amount.toString(),
        ) ||
        facts.outputs.length != 1 ||
        facts.outputs.single.address != quote.destination ||
        facts.outputs.single.amount.value + facts.fee.value != total ||
        !matchesMixedReview(
          quote,
          total,
          facts.fee,
          facts.outputs.single.amount,
        ) ||
        facts.fee.value > maximum.value ||
        evidence['fee'] != facts.fee.toString() ||
        evidence['net'] != facts.outputs.single.amount.toString() ||
        evidence['destination'] != quote.destination) {
      refuse();
    }
    final summary = ArkClaimRecovery(
      txid: txid,
      destination: destination,
      net: facts.outputs.single.amount,
      fee: facts.fee,
    );
    final stored = operation.claimRecovery;
    if (stored != null &&
        (stored.txid != summary.txid ||
            stored.destination != summary.destination ||
            stored.net != summary.net ||
            stored.fee != summary.fee)) {
      refuse();
    }
    return ArkSavedClaim._(
      raw,
      summary,
      List.unmodifiable(facts.inputs.map((input) => input.outpoint)),
    );
  }

  static bool matchesMixedReview(
    ArkQuote quote,
    BigInt total,
    Sats fee,
    Sats net,
  ) =>
      quote.reserveOutpoints.isEmpty ||
      (quote.amount.value == total && quote.fee == fee && quote.net == net);
}
