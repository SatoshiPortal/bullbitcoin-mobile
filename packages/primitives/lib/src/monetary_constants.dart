abstract final class ConversionConstants {
  static final satsAmountOfOneBitcoin = BigInt.from(100_000_000);
  static final maxBitcoinAmount = BigInt.from(21_000_000); // 21 million BTC
  static final maxSatsAmount = maxBitcoinAmount * satsAmountOfOneBitcoin;
}

abstract final class AssetConstants {
  static const lbtcMainnet =
      '6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static const lbtcTestnet =
      '144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49';
}
