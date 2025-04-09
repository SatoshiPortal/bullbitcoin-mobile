import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';

class FeesDatasource {
  final Dio _http;
  final String _baseUrl;

  FeesDatasource({
    Dio? http,
    String? baseUrl,
  })  : _http = http ?? Dio(),
        _baseUrl = baseUrl ?? 'https://${ApiServiceConstants.bbMempoolUrlPath}';

  Future<FeeOptions> getBitcoinNetworkFeeOptions({
    required bool isTestnet,
  }) async {
    final testnet = isTestnet ? '/testnet' : '';
    final url = '$_baseUrl$testnet/api/v1/fees/recommended';

    final resp = await _http.get(url);
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
      fastest: NetworkFee.relative(1),
      economic: NetworkFee.relative(0.1),
      slow: NetworkFee.relative(0.1),
    );

    return feeOptions;
  }
}
