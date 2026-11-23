import 'package:electrum/electrum.dart';

Future<bool> hasCustomBitcoinOnionServer(
  ElectrumServers servers,
  ElectrumServerNetwork network,
) async {
  final bitcoinNetwork = ElectrumServerNetwork.fromEnvironment(
    environment: network.environment,
    isLiquid: false,
  );
  final result = await servers.hasCustomOnionServer(network: bitcoinNetwork);
  return result.fold((value) => value, (_) => false);
}
