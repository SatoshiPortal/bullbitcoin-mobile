import 'package:bb_mobile/core/electrum/application/usecases/ensure_online_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/status/domain/ports/electrum_connectivity_port.dart';

class ElectrumConnectivityFacade implements ElectrumConnectivityPort {
  final EnsureOnlineElectrumServersUsecase _ensureOnlineElectrumServersUsecase;

  ElectrumConnectivityFacade({
    required EnsureOnlineElectrumServersUsecase
    ensureOnlineElectrumServersUsecase,
  }) : _ensureOnlineElectrumServersUsecase = ensureOnlineElectrumServersUsecase;

  @override
  Future<bool> ensureServersInUseAreOnlineForNetwork({required bool isLiquid}) {
    return _ensureOnlineElectrumServersUsecase.execute(isLiquid: isLiquid);
  }
}
