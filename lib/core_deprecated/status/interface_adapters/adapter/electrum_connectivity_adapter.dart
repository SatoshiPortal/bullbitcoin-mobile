import 'package:bb_mobile/core_deprecated/electrum/application/dtos/requests/check_for_online_electrum_servers_request.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/check_for_online_electrum_servers_usecase.dart';
import 'package:bb_mobile/core_deprecated/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';

class ElectrumConnectivityAdapter implements ElectrumConnectivityPort {
  final CheckForOnlineElectrumServersUsecase
  _checkForOnlineElectrumServersUsecase;

  ElectrumConnectivityAdapter({
    required CheckForOnlineElectrumServersUsecase
    checkForOnlineElectrumServersUsecase,
  }) : _checkForOnlineElectrumServersUsecase =
           checkForOnlineElectrumServersUsecase;

  @override
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network) {
    final request = CheckForOnlineElectrumServersRequest(
      isLiquid: network.isLiquid,
    );
    return _checkForOnlineElectrumServersUsecase.execute(request);
  }
}
