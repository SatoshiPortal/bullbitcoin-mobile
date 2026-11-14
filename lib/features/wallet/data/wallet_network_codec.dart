import 'package:bb_mobile/features/wallet/domain/wallet.dart';

/// Persisted names are an explicit contract, independent of enum ordering.
abstract final class WalletNetworkCodec {
  static String encode(Network network) => switch (network) {
    Network.bitcoinMainnet => 'bitcoinMainnet',
    Network.bitcoinTestnet => 'bitcoinTestnet',
    Network.bitcoinRegtest => 'bitcoinRegtest',
    Network.liquidMainnet => 'liquidMainnet',
    Network.liquidTestnet => 'liquidTestnet',
    Network.liquidRegtest => 'liquidRegtest',
  };

  static Network decode(String value) => switch (value) {
    'bitcoinMainnet' => Network.bitcoinMainnet,
    'bitcoinTestnet' => Network.bitcoinTestnet,
    'bitcoinRegtest' => Network.bitcoinRegtest,
    'liquidMainnet' => Network.liquidMainnet,
    'liquidTestnet' => Network.liquidTestnet,
    'liquidRegtest' => Network.liquidRegtest,
    _ => throw const FormatException('Unresolved wallet network'),
  };
}
