import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_settlement.dart';

/// Maps the validated Bullnym settlement projection into the Get Paid-owned
/// presentation projection. A null input (no server classification) maps to a
/// null output so the history list omits the label rather than assuming
/// Bitcoin.
GetPaidSettlement? mapBullnymSettlementToGetPaid(
  BullnymGetPaidSettlement? settlement,
) {
  if (settlement == null) return null;
  return GetPaidSettlement(
    kind: _kind(settlement.kind),
    fiat: [for (final leg in settlement.fiat) _fiatLeg(leg)],
    bitcoin: [for (final leg in settlement.bitcoin) _bitcoinLeg(leg)],
    overrideReason: settlement.overrideReason == null
        ? null
        : _overrideReason(settlement.overrideReason!),
  );
}

GetPaidSettlementKind _kind(BullnymSettlementKind kind) => switch (kind) {
  BullnymSettlementKind.bitcoin => GetPaidSettlementKind.bitcoin,
  BullnymSettlementKind.fiat => GetPaidSettlementKind.fiat,
  BullnymSettlementKind.mixed => GetPaidSettlementKind.mixed,
  BullnymSettlementKind.unavailable => GetPaidSettlementKind.unavailable,
};

GetPaidFiatSettlementLeg _fiatLeg(BullnymFiatSettlementLeg leg) =>
    GetPaidFiatSettlementLeg(
      amountMinor: leg.amountMinor,
      currency: leg.currency,
      orderId: leg.orderId,
      status: _legStatus(leg.status),
    );

GetPaidBitcoinSettlementLeg _bitcoinLeg(BullnymBitcoinSettlementLeg leg) =>
    GetPaidBitcoinSettlementLeg(
      amountSat: leg.amountSat,
      status: _legStatus(leg.status),
    );

GetPaidSettlementLegStatus _legStatus(BullnymSettlementLegStatus status) =>
    switch (status) {
      BullnymSettlementLegStatus.pending => GetPaidSettlementLegStatus.pending,
      BullnymSettlementLegStatus.settled => GetPaidSettlementLegStatus.settled,
      BullnymSettlementLegStatus.problem => GetPaidSettlementLegStatus.problem,
      // A leg status the strict parser never emits still fails safe to
      // unavailable rather than being presented as a definite state.
      BullnymSettlementLegStatus.unavailable ||
      BullnymSettlementLegStatus.unknown =>
        GetPaidSettlementLegStatus.unavailable,
    };

GetPaidFiatOverrideReason _overrideReason(
  BullnymFiatConversionOverrideReason reason,
) => switch (reason) {
  BullnymFiatConversionOverrideReason.belowMinimum =>
    GetPaidFiatOverrideReason.belowMinimum,
  BullnymFiatConversionOverrideReason.invalidSplit =>
    GetPaidFiatOverrideReason.invalidSplit,
  BullnymFiatConversionOverrideReason.conversionUnavailable =>
    GetPaidFiatOverrideReason.conversionUnavailable,
  BullnymFiatConversionOverrideReason.unknown =>
    GetPaidFiatOverrideReason.unknown,
};
