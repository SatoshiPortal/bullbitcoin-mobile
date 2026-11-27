part of 'spend.dart';

/// Override only the commands a consumer is expected to call. An unexpected
/// command throws instead of pretending that a payment succeeded.
class FakeSpend extends _SpendPreviews {
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected Spend call: ${invocation.memberName}');
}

abstract final class SpendFixtures {
  static PreparedBitcoinSpend preparedBitcoin({
    required String unsignedPsbt,
    required Sats fee,
    int txSize = 0,
    bool isToSelf = false,
    List<Sats> recipientAmountsSat = const [],
    UnsignedSpend? native,
  }) => PreparedBitcoinSpend._(
    native,
    unsignedPsbt: unsignedPsbt,
    fee: fee,
    txSize: txSize,
    isToSelf: isToSelf,
    recipientAmountsSat: recipientAmountsSat,
  );

  static PreparedLiquidSpend preparedLiquid({
    required String unsignedPset,
    required Sats fee,
    required Sats amountSent,
    int discountedVsize = 1,
    UnsignedSpend? native,
  }) => PreparedLiquidSpend._(
    native,
    unsignedPset: unsignedPset,
    fee: fee,
    amountSent: amountSent,
    discountedVsize: discountedVsize,
  );

  static SignedBitcoinSpend signedBitcoin(
    String transaction, {
    int txSize = 0,
  }) => SignedBitcoinSpend._(null, transaction, txSize);

  static SignedLiquidSpend signedLiquid(String pset) =>
      SignedLiquidSpend._(null, pset);

  static PreparedLiquidConsolidation consolidation({
    required int transactionCount,
    required Sats totalFee,
  }) => PreparedLiquidConsolidation._(null, transactionCount, totalFee);

  /// The pure transaction comparison used before production signing handoff.
  static Result<void, SpendFailure> verifyBitcoin({
    required String unsignedPsbt,
    required String signedTransaction,
    required bool isPsbt,
  }) => _bitcoinEvidence(
    unsignedPsbt,
    signedTransaction,
    isPsbt,
    requireFinalized: false,
  ).map((_) {});
}
