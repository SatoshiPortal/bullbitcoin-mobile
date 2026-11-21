import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:electrum/electrum.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';

import '../tor_settings/domain/tor_preferences.dart';
import 'domain/check_all_service_status_usecase.dart';
import 'domain/check_electrum_status_usecase.dart';
import 'domain/check_service_status_usecase.dart';
import 'presentation/service_status_cubit.dart';

class StatusCheckLocator {
  static void setup(
    GetIt locator, {
    required Future<Result<NetworkEnv?, Failure>> Function() readDefaultNetwork,
    required Future<void> Function(BitcoinNetwork) checkBitcoinFees,
    required Future<bool> Function() isTorRequired,
    required ReadTorPreferences readTorPreferences,
  }) {
    locator.registerFactory<ServiceStatusCubit>(
      () => ServiceStatusCubit(
        checkServiceStatusUsecase: CheckServiceStatusUsecase(
          readDefaultNetwork: readDefaultNetwork,
          checkAllServiceStatusUsecase: CheckAllServiceStatusUsecase(
            checkElectrumStatus: CheckElectrumStatusUsecase(
              electrumServersPort: locator<ElectrumServersPort>(),
              serverStatusPort: locator<ServerStatusPort>(),
            ),
            getIndexPrice: Pricer.getIndexPrice,
            payjoinPolicy: locator<PayjoinPolicyAccess>(),
            payjoinDiagnostics: locator<PayjoinDiagnostics>(),
            checkBitcoinFees: checkBitcoinFees,
            isTorRequired: isTorRequired,
            checkServerConnection: locator<RecoverBullFacade>().checkServer,
            readTorPreferences: readTorPreferences,
            tor: locator<Tor>(),
          ),
        ),
      ),
    );
  }
}
