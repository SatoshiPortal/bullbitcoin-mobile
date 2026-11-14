import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

class GetNetworkFeesUsecase {
  final FeesRepository _feesRepository;
  final SettingsRepository _settingsRepository;

  GetNetworkFeesUsecase({
    required this._feesRepository,
    required this._settingsRepository,
  });

  Future<FeeOptions> execute({required bool isLiquid, Network? network}) async {
    try {
      final requestedNetwork =
          network ??
          Network.fromEnvironment(
            environment:
                (await _settingsRepository.fetch()).environment.networkEnv,
            isLiquid: isLiquid,
          );
      if (requestedNetwork.isLiquid != isLiquid) {
        throw GetNetworkFeesException('Fee network does not match asset');
      }
      return await _feesRepository.getNetworkFees(network: requestedNetwork);
    } catch (e) {
      log.warning('Network fee estimation unavailable: ${e.runtimeType}');
      throw GetNetworkFeesException('Error while getting network fees.');
    }
  }
}

class GetNetworkFeesException extends BullException {
  GetNetworkFeesException(super.message);
}
