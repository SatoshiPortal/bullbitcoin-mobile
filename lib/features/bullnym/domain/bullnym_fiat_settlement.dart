const bullnymFiatSettlementContractVersion = 1;

enum BullnymFiatSettlementProduct {
  lightningAddress('lightning_address'),
  paymentPage('payment_page'),
  pos('pos'),
  invoice('invoice');

  final String wire;

  const BullnymFiatSettlementProduct(this.wire);

  static BullnymFiatSettlementProduct? fromWire(String value) {
    for (final product in values) {
      if (product.wire == value) return product;
    }
    return null;
  }
}

enum BullnymSettlementKind { bitcoin, fiat, mixed, unavailable }

enum BullnymSettlementLegStatus { pending, settled, problem, unavailable }

enum BullnymFiatConversionOverrideReason {
  belowMinimum,
  invalidSplit,
  conversionUnavailable,
  ambiguousCreate,
  unknown,
}

final class BullnymFiatSettlementLeg {
  final int? amountMinor;
  final int? quotedAmountMinor;
  final int? executionRateMinorPerBtc;
  final String currency;
  final String orderId;
  final BullnymSettlementLegStatus status;

  const BullnymFiatSettlementLeg({
    required this.amountMinor,
    required this.quotedAmountMinor,
    required this.executionRateMinorPerBtc,
    required this.currency,
    required this.orderId,
    required this.status,
  });
}

final class BullnymBitcoinSettlementLeg {
  final int amountSat;
  final String network;
  final BullnymSettlementLegStatus status;

  const BullnymBitcoinSettlementLeg({
    required this.amountSat,
    required this.network,
    required this.status,
  });
}

final class BullnymGetPaidSettlement {
  final BullnymSettlementKind kind;
  final List<BullnymFiatSettlementLeg> fiat;
  final List<BullnymBitcoinSettlementLeg> bitcoin;
  final BullnymFiatConversionOverrideReason? overrideReason;
  final int? fiatPercentage;
  final int? creationRateMinorPerBtc;
  final String? creationRateCurrency;

  const BullnymGetPaidSettlement({
    required this.kind,
    this.fiat = const [],
    this.bitcoin = const [],
    this.overrideReason,
    this.fiatPercentage,
    this.creationRateMinorPerBtc,
    this.creationRateCurrency,
  });

  static const unavailable = BullnymGetPaidSettlement(
    kind: BullnymSettlementKind.unavailable,
  );
}

enum BullnymCredentialStatus {
  absent,
  active,
  deletionPending,
  unknown;

  static BullnymCredentialStatus fromWire(String? value) => switch (value) {
    'absent' => absent,
    'active' => active,
    'deletion_pending' => deletionPending,
    _ => unknown,
  };

  bool get isActive => this == active;
}

final class BullnymFiatSettlementSetting {
  final BullnymFiatSettlementProduct product;
  final int fiatPercentage;
  final String fiatCurrency;

  const BullnymFiatSettlementSetting({
    required this.product,
    required this.fiatPercentage,
    required this.fiatCurrency,
  });
}

final class BullnymFiatSettlementConfiguration {
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
