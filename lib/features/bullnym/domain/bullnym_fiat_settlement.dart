// Bullnym fiat-settlement wire domain types.
//
// The client submits signed per-product fiat-settlement configuration and
// reads back the server-owned configuration. It performs no eligibility, FX,
// KYC, routing, or order logic — those are entirely server-owned.

/// The Bullnym contract version pinned into every fiat-settlement request.
const int bullnymFiatSettlementContractVersion = 1;

/// The four Get Paid products, each configured independently. The [wire] value
/// is the exact server path segment / signed-field string.
enum BullnymFiatSettlementProduct {
  lightningAddress('lightning_address'),
  paymentPage('payment_page'),
  pos('pos'),
  invoice('invoice');

  const BullnymFiatSettlementProduct(this.wire);

  final String wire;
}

/// Coarse settlement classification for a received Get Paid payment, shown as
/// the single label in history lists. `unavailable` is the fail-closed value
/// for anything this client version cannot confidently interpret — it must
/// NEVER be silently shown as Bitcoin-only.
enum BullnymSettlementKind { bitcoin, fiat, mixed, unavailable }

enum BullnymSettlementLegStatus { pending, settled, unavailable, unknown }

/// Why a configured fiat conversion was overridden to all-Bitcoin.
enum BullnymFiatConversionOverrideReason {
  belowMinimum,
  invalidSplit,
  conversionUnavailable,
  unknown,
}

/// One fiat settlement order (private, merchant-only). `amountMinor` is present
/// only once settled.
class BullnymFiatSettlementLeg {
  final int? amountMinor;
  final String currency;
  final String orderId;
  final BullnymSettlementLegStatus status;

  const BullnymFiatSettlementLeg({
    required this.amountMinor,
    required this.currency,
    required this.orderId,
    required this.status,
  });
}

/// The Bitcoin-wallet portion of a mixed settlement.
class BullnymBitcoinSettlementLeg {
  final int amountSat;
  final String network;
  final BullnymSettlementLegStatus status;

  const BullnymBitcoinSettlementLeg({
    required this.amountSat,
    required this.network,
    required this.status,
  });
}

/// Private, structured settlement details for one Get Paid payment. Parsed
/// tolerantly: any shape this client cannot interpret yields
/// [BullnymSettlementKind.unavailable] with empty legs and no override, so the
/// UI shows "Settlement details unavailable" rather than a wrong breakdown.
class BullnymGetPaidSettlement {
  final BullnymSettlementKind kind;
  final List<BullnymFiatSettlementLeg> fiat;
  final List<BullnymBitcoinSettlementLeg> bitcoin;
  final BullnymFiatConversionOverrideReason? overrideReason;

  const BullnymGetPaidSettlement({
    required this.kind,
    this.fiat = const [],
    this.bitcoin = const [],
    this.overrideReason,
  });

  static const unavailable = BullnymGetPaidSettlement(
    kind: BullnymSettlementKind.unavailable,
  );

  /// Tolerant parse of the optional `settlement_details` + `fiat_conversion`
  /// fields on a signed Get Paid transaction. Returns null when neither is
  /// present (plain Bitcoin payment, no fiat config — the caller treats null as
  /// Bitcoin). Returns [unavailable] when present-but-uninterpretable.
  static BullnymGetPaidSettlement? tryParse(Map<String, dynamic> json) {
    final override = json['fiat_conversion'];
    final details = json['settlement_details'];
    if (override == null && details == null) return null;

    try {
      // An override means the whole payment was kept in Bitcoin.
      if (override is Map<String, dynamic> &&
          override['status'] == 'overridden') {
        return BullnymGetPaidSettlement(
          kind: BullnymSettlementKind.bitcoin,
          overrideReason: _reason(override['reason']),
        );
      }
      if (details is! Map<String, dynamic>) return unavailable;
      final kind = switch (details['kind']) {
        'fiat' => BullnymSettlementKind.fiat,
        'mixed' => BullnymSettlementKind.mixed,
        _ => BullnymSettlementKind.unavailable,
      };
      if (kind == BullnymSettlementKind.unavailable) return unavailable;
      return BullnymGetPaidSettlement(
        kind: kind,
        fiat: _fiatLegs(details['fiat']),
        bitcoin: _bitcoinLegs(details['bitcoin']),
      );
    } catch (_) {
      return unavailable;
    }
  }

  static BullnymFiatConversionOverrideReason _reason(Object? v) =>
      switch (v) {
        'below_minimum' => BullnymFiatConversionOverrideReason.belowMinimum,
        'invalid_split' => BullnymFiatConversionOverrideReason.invalidSplit,
        'conversion_unavailable' =>
          BullnymFiatConversionOverrideReason.conversionUnavailable,
        _ => BullnymFiatConversionOverrideReason.unknown,
      };

  static BullnymSettlementLegStatus _legStatus(Object? v) => switch (v) {
    'pending' => BullnymSettlementLegStatus.pending,
    'settled' => BullnymSettlementLegStatus.settled,
    'unavailable' => BullnymSettlementLegStatus.unavailable,
    _ => BullnymSettlementLegStatus.unknown,
  };

  static List<BullnymFiatSettlementLeg> _fiatLegs(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          BullnymFiatSettlementLeg(
            amountMinor: e['amount_minor'] is int
                ? e['amount_minor'] as int
                : null,
            currency: e['currency'] is String ? e['currency'] as String : '',
            orderId: e['order_id'] is String ? e['order_id'] as String : '',
            status: _legStatus(e['status']),
          ),
    ];
  }

  static List<BullnymBitcoinSettlementLeg> _bitcoinLegs(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          BullnymBitcoinSettlementLeg(
            amountSat: e['amount_sat'] is int ? e['amount_sat'] as int : 0,
            network: e['network'] is String ? e['network'] as String : '',
            status: _legStatus(e['status']),
          ),
    ];
  }
}

/// Lifecycle status of the server-held encrypted Bull Bitcoin credential.
enum BullnymCredentialStatus {
  absent,
  active,
  deletionPending,

  /// A status value this client version does not recognize. Fails closed:
  /// treated as not-active for gating so we never assume a credential exists.
  unknown;

  static BullnymCredentialStatus fromWire(String? value) {
    switch (value) {
      case 'absent':
        return BullnymCredentialStatus.absent;
      case 'active':
        return BullnymCredentialStatus.active;
      case 'deletion_pending':
        return BullnymCredentialStatus.deletionPending;
      default:
        return BullnymCredentialStatus.unknown;
    }
  }

  bool get isActive => this == BullnymCredentialStatus.active;
}

/// One product's server-confirmed fiat-settlement setting. A `fiatPercentage`
/// of 0 means Bitcoin-only (the product will not appear in a configuration
/// response as an explicit setting when it is Bitcoin-only).
class BullnymFiatSettlementSetting {
  final BullnymFiatSettlementProduct product;
  final int fiatPercentage;
  final String? fiatCurrency;

  const BullnymFiatSettlementSetting({
    required this.product,
    required this.fiatPercentage,
    required this.fiatCurrency,
  });
}

/// The server-owned fiat-settlement configuration returned by set / get /
/// disable operations. The scoped credential is never present in this payload.
class BullnymFiatSettlementConfiguration {
  final List<BullnymFiatSettlementSetting> settings;
  final BullnymCredentialStatus credentialStatus;

  const BullnymFiatSettlementConfiguration({
    required this.settings,
    required this.credentialStatus,
  });

  BullnymFiatSettlementSetting? settingFor(
    BullnymFiatSettlementProduct product,
  ) {
    for (final setting in settings) {
      if (setting.product == product) return setting;
    }
    return null;
  }
}
