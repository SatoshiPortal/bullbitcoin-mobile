/// Per-rail buy limits mirrored from the Bull Bitcoin exchange configuration
/// (MIN_LIMIT_BUY_ON_CHAIN_SATS, MIN_LIMIT_BUY_LIQUID_SATS,
/// MAX_LIMIT_BUY_LN_INVOICE_SATS). Bitcoin and Liquid carry a minimum;
/// Lightning carries a maximum. `limitAmountLimits` turns them into the
/// amount step's fiat bounds.
abstract final class LimitOrderAmountLimits {
  static const int minOnChainSats = 100000;
  static const int minLiquidSats = 1000;
  static const int maxLightningSats = 25000000;
  static const int satsPerBtc = 100000000;
}
