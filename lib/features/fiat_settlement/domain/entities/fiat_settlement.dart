import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';

/// The four Get Paid products configured independently for fiat settlement.
enum FiatSettlementProduct {
  lightningAddress,
  paymentPage,
  pos,
  invoice;

  BullnymFiatSettlementProduct get wire => switch (this) {
    FiatSettlementProduct.lightningAddress =>
      BullnymFiatSettlementProduct.lightningAddress,
    FiatSettlementProduct.paymentPage =>
      BullnymFiatSettlementProduct.paymentPage,
    FiatSettlementProduct.pos => BullnymFiatSettlementProduct.pos,
    FiatSettlementProduct.invoice => BullnymFiatSettlementProduct.invoice,
  };

  /// The URL path segment for this product (matches the Bullnym wire id).
  String get pathId => wire.wire;

  static FiatSettlementProduct fromWire(BullnymFiatSettlementProduct product) =>
      switch (product) {
        BullnymFiatSettlementProduct.lightningAddress =>
          FiatSettlementProduct.lightningAddress,
        BullnymFiatSettlementProduct.paymentPage =>
          FiatSettlementProduct.paymentPage,
        BullnymFiatSettlementProduct.pos => FiatSettlementProduct.pos,
        BullnymFiatSettlementProduct.invoice => FiatSettlementProduct.invoice,
      };
}

/// The seven approved fiat settlement currencies. The [code] is the server /
/// signed-field value; the withdrawal disclosure for each lives in the app's
/// localized content, keyed by this enum.
enum FiatCurrency {
  cad('CAD'),
  eur('EUR'),
  mxn('MXN'),
  crc('CRC'),
  cop('COP'),
  ars('ARS'),
  usd('USD');

  const FiatCurrency(this.code);

  final String code;

  static FiatCurrency? fromCode(String? code) {
    if (code == null) return null;
    for (final currency in FiatCurrency.values) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}

/// How a product settles a received payment, derived from the fiat percentage.
enum FiatSettlementMode { bitcoinOnly, mixed, fiatOnly }

FiatSettlementMode fiatSettlementModeForPercentage(int percentage) {
  if (percentage <= 0) return FiatSettlementMode.bitcoinOnly;
  if (percentage >= 100) return FiatSettlementMode.fiatOnly;
  return FiatSettlementMode.mixed;
}

/// A product's current server-confirmed settlement configuration, used for
/// the Get Paid summaries and to preselect the edit flow.
class FiatSettlementProductConfig {
  final FiatSettlementProduct product;
  final int fiatPercentage;
  final FiatCurrency? currency;

  const FiatSettlementProductConfig({
    required this.product,
    required this.fiatPercentage,
    required this.currency,
  });

  FiatSettlementMode get mode =>
      fiatSettlementModeForPercentage(fiatPercentage);

  bool get isBitcoinOnly => mode == FiatSettlementMode.bitcoinOnly;
}

/// The server-confirmed configuration across products plus whether Bullnym
/// currently holds an active credential (which decides whether a subsequent
/// change must resupply the scoped key).
class FiatSettlementConfigurationView {
  final List<FiatSettlementProductConfig> products;
  final bool credentialActive;

  const FiatSettlementConfigurationView({
    required this.products,
    required this.credentialActive,
  });

  factory FiatSettlementConfigurationView.fromWire(
    BullnymFiatSettlementConfiguration config,
  ) {
    return FiatSettlementConfigurationView(
      products: [
        for (final setting in config.settings)
          FiatSettlementProductConfig(
            product: FiatSettlementProduct.fromWire(setting.product),
            fiatPercentage: setting.fiatPercentage,
            currency: FiatCurrency.fromCode(setting.fiatCurrency),
          ),
      ],
      credentialActive: config.credentialStatus.isActive,
    );
  }

  /// The saved config for [product], defaulting to Bitcoin-only when absent.
  FiatSettlementProductConfig configFor(FiatSettlementProduct product) {
    for (final config in products) {
      if (config.product == product) return config;
    }
    return FiatSettlementProductConfig(
      product: product,
      fiatPercentage: 0,
      currency: null,
    );
  }
}
