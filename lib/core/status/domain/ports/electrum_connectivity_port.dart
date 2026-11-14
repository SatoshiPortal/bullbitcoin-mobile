import 'package:bb_mobile/features/wallet/domain/wallet.dart';

abstract class ElectrumConnectivityPort {
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network);
}
