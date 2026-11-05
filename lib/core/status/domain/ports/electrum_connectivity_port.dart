import 'package:wallet/wallet.dart';

abstract class ElectrumConnectivityPort {
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network);
}
