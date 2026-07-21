// Get Paid-owned settlement presentation projection.
//
// Get Paid does not consume the Bullnym transport/domain settlement types in
// its widgets. The list use-case maps the validated Bullnym projection into
// these Get Paid types at the feature boundary, and history/detail screens
// render only from here.

/// Coarse settlement classification for a received Get Paid payment. There is
/// deliberately no "bitcoin-by-default": a payment with no server-provided
/// classification is represented by a null projection, never by this enum.
enum GetPaidSettlementKind { bitcoin, fiat, mixed, unavailable }

/// Per-leg lifecycle in the Get Paid presentation. Fiat legs use
/// pending/settled/unavailable; Bitcoin legs use pending/settled/problem.
enum GetPaidSettlementLegStatus { pending, settled, problem, unavailable }

/// Why a configured fiat conversion was overridden to all-Bitcoin. `unknown`
/// covers a reason this client version does not recognize (rendered with the
/// generic override copy).
enum GetPaidFiatOverrideReason {
  belowMinimum,
  invalidSplit,
  conversionUnavailable,
  unknown,
}

/// One private fiat settlement leg. [amountMinor] is present only once settled.
class GetPaidFiatSettlementLeg {
  final int? amountMinor;
  final String currency;
  final String orderId;
  final GetPaidSettlementLegStatus status;

  const GetPaidFiatSettlementLeg({
    required this.amountMinor,
    required this.currency,
    required this.orderId,
    required this.status,
  });
}

/// The Bitcoin-wallet portion of a mixed settlement.
class GetPaidBitcoinSettlementLeg {
  final int amountSat;
  final GetPaidSettlementLegStatus status;

  const GetPaidBitcoinSettlementLeg({
    required this.amountSat,
    required this.status,
  });
}

/// The Get Paid settlement projection shown on the history and detail screens.
class GetPaidSettlement {
  final GetPaidSettlementKind kind;
  final List<GetPaidFiatSettlementLeg> fiat;
  final List<GetPaidBitcoinSettlementLeg> bitcoin;
  final GetPaidFiatOverrideReason? overrideReason;

  const GetPaidSettlement({
    required this.kind,
    this.fiat = const [],
    this.bitcoin = const [],
    this.overrideReason,
  });
}
