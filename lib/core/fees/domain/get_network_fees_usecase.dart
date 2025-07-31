import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class GetNetworkFeesUsecase {
  final FeesRepository _feesRepository;
  final SettingsRepository _settingsRepository;

  GetNetworkFeesUsecase({
    required FeesRepository feesRepository,
    required SettingsRepository settingsRepository,
  }) : _feesRepository = feesRepository,
       _settingsRepository = settingsRepository;

  Future<FeeOptions> execute({required bool isLiquid}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: isLiquid,
      );

      return await _feesRepository.getNetworkFees(network: network);
    } catch (e) {
      log.severe('Network fees: $e');
      throw GetNetworkFeesException('Error while getting network fees.');
    }
  }
}

class GetNetworkFeesException implements Exception {
  final String message;

  GetNetworkFeesException(this.message);

  @override
  String toString() => '[GetNetworkFeesUsecase]: $message';
}
