import 'package:bb_mobile/core/tor/infrastructure/services/tor_connectivity_service.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';

class CheckTorProxyConnectionUsecase {
  final TorConnectivityService _torConnectivityService;

  CheckTorProxyConnectionUsecase({
    required TorConnectivityService torConnectivityService,
  }) : _torConnectivityService = torConnectivityService;

  Future<TorStatus> execute(int port) async {
    return _torConnectivityService.checkConnection(port);
  }
}
