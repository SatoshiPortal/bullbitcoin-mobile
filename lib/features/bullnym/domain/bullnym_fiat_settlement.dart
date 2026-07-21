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

/// Per-leg lifecycle. Fiat legs are `pending`, `settled`, or `unavailable`;
/// Bitcoin legs are `pending`, `settled`, or `problem`. `unknown` is retained
/// for exhaustive switches but the strict parser never produces it — an
/// unrecognized leg status invalidates the whole projection instead.
enum BullnymSettlementLegStatus {
  pending,
  settled,
  problem,
  unavailable,
  unknown,
}

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

/// Private, structured settlement projection for one Get Paid payment.
///
/// Parsing is tolerant-outer / strict-inner: any JSON-type surprise or any
/// value this client version cannot confidently interpret fails closed to
/// [BullnymSettlementKind.unavailable] (empty legs, no override) rather than
/// throwing or fabricating a breakdown. Classification is read from the
/// authoritative top-level `settlement_kind`; it is NEVER derived from field
/// presence or from `settlement_details.kind` alone.
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

  static const _bitcoin = BullnymGetPaidSettlement(
    kind: BullnymSettlementKind.bitcoin,
  );

  static final RegExp _canonicalUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static const String _nilUuid = '00000000-0000-0000-0000-000000000000';

  /// The seven approved settlement currencies, pinned uppercase. Any other
  /// currency string invalidates the leg (and therefore the projection).
  static const Set<String> _supportedCurrencies = {
    'ARS',
    'CAD',
    'COP',
    'CRC',
    'EUR',
    'MXN',
    'USD',
  };

  /// Strict parse of the merchant settlement projection carried on a signed Get
  /// Paid transaction. Returns:
  ///
  /// - `null` when the top-level `settlement_kind` field is ABSENT (an old
  ///   server row with no projection). The caller maps null to its own no-data
  ///   state — this is NEVER interpreted as Bitcoin.
  /// - a settlement with the read [kind] when the payload is internally
  ///   consistent with the contract.
  /// - [unavailable] for any present-but-uninterpretable or inconsistent
  ///   payload (unknown enum, tagged-kind mismatch, invalid/empty legs, an
  ///   override or details attached to the wrong kind, a JSON type error).
  static BullnymGetPaidSettlement? tryParse(Map<String, dynamic> json) {
    // Absent classification is the no-data path (old server). Presence is what
    // distinguishes it from a server-sent `unavailable`.
    if (!json.containsKey('settlement_kind')) return null;

    try {
      final details = json['settlement_details'];
      final override = json['fiat_conversion'];
      switch (json['settlement_kind']) {
        case 'bitcoin':
          return _parseBitcoin(details: details, override: override);
        case 'fiat':
          return _parseFiat(details: details, override: override);
        case 'mixed':
          return _parseMixed(details: details, override: override);
        case 'unavailable':
          // A trustworthy `unavailable` carries neither field; any attached
          // detail is itself inconsistent, so fail closed either way.
          return unavailable;
        default:
          // Unknown or non-string classification → fail closed.
          return unavailable;
      }
    } catch (_) {
      return unavailable;
    }
  }

  static BullnymGetPaidSettlement _parseBitcoin({
    required Object? details,
    required Object? override,
  }) {
    // Ordinary Bitcoin settlement carries no structured details.
    if (details != null) return unavailable;
    if (override == null) return _bitcoin;
    // The only Bitcoin-kind detail is a pre-funding conversion override. An
    // unknown reason is tolerated (it renders as a generic override note); a
    // malformed override envelope fails closed.
    if (override is! Map<String, dynamic> ||
        override['status'] != 'overridden') {
      return unavailable;
    }
    return BullnymGetPaidSettlement(
      kind: BullnymSettlementKind.bitcoin,
      overrideReason: _reason(override['reason']),
    );
  }

  static BullnymGetPaidSettlement _parseFiat({
    required Object? details,
    required Object? override,
  }) {
    // A fiat projection never carries a Bitcoin-only conversion override.
    if (override != null) return unavailable;
    if (details is! Map<String, dynamic>) return unavailable;
    // The tagged detail kind must equal the top-level classification.
    if (details['kind'] != 'fiat') return unavailable;
    // A fiat projection has no bitcoin array.
    if (details.containsKey('bitcoin')) return unavailable;
    final fiat = _fiatLegs(details['fiat']);
    if (fiat == null || fiat.isEmpty) return unavailable;
    return BullnymGetPaidSettlement(
      kind: BullnymSettlementKind.fiat,
      fiat: fiat,
    );
  }

  static BullnymGetPaidSettlement _parseMixed({
    required Object? details,
    required Object? override,
  }) {
    if (override != null) return unavailable;
    if (details is! Map<String, dynamic>) return unavailable;
    if (details['kind'] != 'mixed') return unavailable;
    final fiat = _fiatLegs(details['fiat']);
    final bitcoin = _bitcoinLegs(details['bitcoin']);
    // A mixed projection requires non-empty valid legs on BOTH sides.
    if (fiat == null || fiat.isEmpty) return unavailable;
    if (bitcoin == null || bitcoin.isEmpty) return unavailable;
    return BullnymGetPaidSettlement(
      kind: BullnymSettlementKind.mixed,
      fiat: fiat,
      bitcoin: bitcoin,
    );
  }

  static BullnymFiatConversionOverrideReason _reason(Object? v) => switch (v) {
    'below_minimum' => BullnymFiatConversionOverrideReason.belowMinimum,
    'invalid_split' => BullnymFiatConversionOverrideReason.invalidSplit,
    'conversion_unavailable' =>
      BullnymFiatConversionOverrideReason.conversionUnavailable,
    _ => BullnymFiatConversionOverrideReason.unknown,
  };

  /// Validates every fiat leg. Returns null if ANY leg is invalid so the whole
  /// projection fails closed to `unavailable` without partial details.
  static List<BullnymFiatSettlementLeg>? _fiatLegs(Object? raw) {
    if (raw is! List) return null;
    final legs = <BullnymFiatSettlementLeg>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) return null;
      final currency = e['currency'];
      if (currency is! String || !_supportedCurrencies.contains(currency)) {
        return null;
      }
      final orderId = e['order_id'];
      if (orderId is! String || !_isCanonicalUuid(orderId)) return null;
      final status = _fiatLegStatus(e['status']);
      if (status == null) return null;
      final amountMinor = e['amount_minor'];
      final int? amount;
      if (status == BullnymSettlementLegStatus.settled) {
        // amount_minor is a strictly positive int only for settled.
        if (amountMinor is! int || amountMinor <= 0) return null;
        amount = amountMinor;
      } else {
        // pending / unavailable: amount_minor must be JSON null (zero is never
        // a pending sentinel).
        if (amountMinor != null) return null;
        amount = null;
      }
      legs.add(
        BullnymFiatSettlementLeg(
          amountMinor: amount,
          currency: currency,
          orderId: orderId,
          status: status,
        ),
      );
    }
    return legs;
  }

  /// Validates every Bitcoin leg. Returns null if ANY leg is invalid.
  static List<BullnymBitcoinSettlementLeg>? _bitcoinLegs(Object? raw) {
    if (raw is! List) return null;
    final legs = <BullnymBitcoinSettlementLeg>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) return null;
      final amountSat = e['amount_sat'];
      if (amountSat is! int || amountSat <= 0) return null;
      // Version one settles Bitcoin legs on Liquid only.
      if (e['network'] != 'liquid') return null;
      final status = _bitcoinLegStatus(e['status']);
      if (status == null) return null;
      legs.add(
        BullnymBitcoinSettlementLeg(
          amountSat: amountSat,
          network: 'liquid',
          status: status,
        ),
      );
    }
    return legs;
  }

  static BullnymSettlementLegStatus? _fiatLegStatus(Object? v) => switch (v) {
    'pending' => BullnymSettlementLegStatus.pending,
    'settled' => BullnymSettlementLegStatus.settled,
    'unavailable' => BullnymSettlementLegStatus.unavailable,
    _ => null,
  };

  static BullnymSettlementLegStatus? _bitcoinLegStatus(Object? v) =>
      switch (v) {
        'pending' => BullnymSettlementLegStatus.pending,
        'settled' => BullnymSettlementLegStatus.settled,
        'problem' => BullnymSettlementLegStatus.problem,
        _ => null,
      };

  static bool _isCanonicalUuid(String value) =>
      value != _nilUuid && _canonicalUuid.hasMatch(value);
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
