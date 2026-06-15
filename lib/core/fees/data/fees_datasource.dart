import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';

class FeesDatasource {
  final GetActiveMempoolServerUsecase _getActiveMempoolServerUsecase;
  final MempoolSettingsRepository _mempoolSettingsRepository;

  /// Builds the HTTP client for a resolved base URL. Injected so tests can
  /// supply a mock; defaults to a real Dio. The base URL is only known at
  /// call time (custom server vs BB, mainnet vs testnet), so this is a
  /// builder rather than a pre-built client.
  final Dio Function(String baseUrl) _dioBuilder;

  FeesDatasource({
    required this._getActiveMempoolServerUsecase,
    required this._mempoolSettingsRepository,
    Dio Function(String baseUrl)? dioBuilder,
  }) : _dioBuilder = dioBuilder ?? _defaultDioBuilder;

  static Dio _defaultDioBuilder(String baseUrl) =>
      Dio(BaseOptions(baseUrl: baseUrl));

  /// Fetches precise (sub-1 sat/vByte) fee rates from the mempool API.
  ///
  /// Tries `/api/v1/fees/precise` first. If it fails for any reason — a
  /// server too old to expose it (404), a transient error, or a malformed
  /// body — falls back to the rounded `/api/v1/fees/recommended` so a
  /// custom/self-hosted mempool keeps working. Both endpoints return the
  /// same JSON shape, so the same model parses either. Throws only when
  /// neither endpoint yields a usable response.
  Future<MempoolFeesModel> fetchBitcoinNetworkFees({
    required bool isTestnet,
  }) async {
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: false,
    );
    final settings = await _mempoolSettingsRepository.fetchByNetwork(network);

    // Determine which mempool server to use.
    String baseUrl;
    if (settings.useForFeeEstimation) {
      // Use custom or default mempool server from settings.
      final server = await _getActiveMempoolServerUsecase.execute(
        isTestnet: isTestnet,
        isLiquid: false,
      );
      baseUrl = server.fullUrl;
    } else {
      // Fall back to BB's mempool.
      baseUrl = isTestnet
          ? 'https://${ApiServiceConstants.testnetMempoolUrlPath}'
          : 'https://${ApiServiceConstants.bbMempoolUrlPath}';
    }

    final http = _dioBuilder(baseUrl);

    final json =
        await _getFees(http, ApiServiceConstants.mempoolPreciseFeesPath) ??
        await _getFees(http, ApiServiceConstants.mempoolRecommendedFeesPath);
    if (json == null) {
      throw MempoolFeesException(
        'No mempool fee endpoint available at $baseUrl',
      );
    }

    return MempoolFeesModel.fromJson(json);
  }

  /// GETs a fee endpoint. Returns the JSON body on a 200 with a JSON object,
  /// or `null` on any failure (non-200, network/Dio error, or a non-object
  /// body) so the caller can fall back to another path.
  Future<Map<String, dynamic>?> _getFees(Dio http, String path) async {
    try {
      final resp = await http.get<dynamic>(path);
      final data = resp.data;
      if (resp.statusCode == 200 && data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } on DioException {
      return null;
    }
  }
}

class MempoolFeesException extends BullException {
  MempoolFeesException(super.message);
}
