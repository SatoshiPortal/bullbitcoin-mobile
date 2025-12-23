import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';

class FeesDatasource {
  final GetActiveMempoolServerUsecase _getActiveMempoolServerUsecase;
  final MempoolSettingsRepository _mempoolSettingsRepository;

  FeesDatasource({
    required GetActiveMempoolServerUsecase getActiveMempoolServerUsecase,
    required MempoolSettingsRepository mempoolSettingsRepository,
  })  : _getActiveMempoolServerUsecase = getActiveMempoolServerUsecase,
        _mempoolSettingsRepository = mempoolSettingsRepository;

  Future<FeeOptions> getBitcoinNetworkFeeOptions({
    required bool isTestnet,
  }) async {
    // Get network settings
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: false,
    );
    final settings = await _mempoolSettingsRepository.fetchByNetwork(network);

    // Determine which mempool server to use
    String baseUrl;
    if (settings.useForFeeEstimation) {
      // Use custom or default mempool server from settings
      final server = await _getActiveMempoolServerUsecase.execute(
        isTestnet: isTestnet,
        isLiquid: false,
      );
      baseUrl = server.fullUrl;
    } else {
      // Fall back to BB's mempool
      baseUrl = isTestnet
          ? 'https://${ApiServiceConstants.testnetMempoolUrlPath}'
          : 'https://${ApiServiceConstants.bbMempoolUrlPath}';
    }

    final http = Dio(BaseOptions(baseUrl: baseUrl));
    const path = '/api/v1/fees/recommended';

    final resp = await http.get(path);
    if (resp.statusCode == null || resp.statusCode != 200) {
      throw 'Error fetching fees from Mempool API (status: ${resp.statusCode})';
    }
    final data = resp.data as Map<String, dynamic>;
    final fastestFee = data['fastestFee'] as int;
    final economyFee = data['economyFee'] as int;
    final minimumFee = data['minimumFee'] as int;

    final feeOptions = FeeOptions(
      fastest: NetworkFee.relative(fastestFee.toDouble()),
      economic: NetworkFee.relative(economyFee.toDouble()),
      slow: NetworkFee.relative(minimumFee.toDouble()),
    );

    return feeOptions;
  }

  Future<FeeOptions> getLiquidNetworkFeeOptions({
    required bool isTestnet,
  }) async {
    const feeOptions = FeeOptions(
      fastest: NetworkFee.relative(0.1),
      economic: NetworkFee.relative(0.1),
      slow: NetworkFee.relative(0.1),
    );

    return feeOptions;
  }
}
