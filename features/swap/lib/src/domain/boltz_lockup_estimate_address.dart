import 'package:primitives/primitives.dart'
    show Network, BitcoinNetwork, LiquidNetwork, UnsupportedNetworkException;

/// Estimation-only Taproot outputs, confidential on Liquid. Never fund these
/// placeholders: the provider supplies the actual swap lockup destination.
String boltzLockupEstimateAddress(Network network) => switch (network) {
  BitcoinNetwork.mainnet =>
    'bc1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskq9pj5n4',
  BitcoinNetwork.signet => throw const UnsupportedNetworkException(),
  BitcoinNetwork.testnet =>
    'tb1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskqjfymf6',
  LiquidNetwork.mainnet => 'lq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0we046p4uqlt24',
  LiquidNetwork.testnet => 'tlq1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0w78z5h5l8mzyz',
  BitcoinNetwork.regtest =>
    'bcrt1p0e9sutev5p0whwkdqdzy6gw03m6g66zuullc4erh80u7qezneskqlswauq',
  LiquidNetwork.regtest => 'el1pqvxwxl7pckz6p4vq0dh7dv8ae3lha97w4wjqls8p508xc2jus85sf3xgkzdkm3qdgmckph0a303qvnfyxsffyszy8s2w5ev5ys93xx0wsrtsarlsuma9',
};
