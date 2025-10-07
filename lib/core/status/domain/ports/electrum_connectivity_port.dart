import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

abstract class ElectrumConnectivityPort {
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network);
}
