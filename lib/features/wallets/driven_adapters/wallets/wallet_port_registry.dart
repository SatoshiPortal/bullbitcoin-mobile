import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/features/wallets/application/ports/wallet_port.dart';
import 'package:bb_mobile/features/wallets/driven_adapters/wallets/bdk_wallet_adapter.dart';
import 'package:bb_mobile/features/wallets/driven_adapters/wallets/lwk_wallet_adapter.dart';

class WalletPortRegistry {
  final Map<Network, WalletPort> _ports;

  WalletPortRegistry({
    required BdkWalletAdapter bdkPort,
    required LwkWalletAdapter lwkPort,
  }) : _ports = {Network.bitcoin: bdkPort, Network.liquid: lwkPort};

  WalletPort getPort(Network network) {
    return _ports[network]!;
  }
}
