import 'package:bb_mobile/core/electrum/application/usecases/check_for_online_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ElectrumConnectivityFacade implements ElectrumConnectivityPort {
  final CheckForOnlineElectrumServersUsecase
  _checkForOnlineElectrumServersUsecase;

  ElectrumConnectivityFacade({
    required CheckForOnlineElectrumServersUsecase
    checkForOnlineElectrumServersUsecase,
  }) : _checkForOnlineElectrumServersUsecase =
           checkForOnlineElectrumServersUsecase;

  @override
  Future<bool> checkServersInUseAreOnlineForNetwork(Network network) {
    return _checkForOnlineElectrumServersUsecase.execute(
      isLiquid: network.isLiquid,
    );
  }
}
