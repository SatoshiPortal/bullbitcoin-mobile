import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';

/// Data source for fetching fee estimates
class FeesDatasource {
  final Dio _http;
  final String _baseUrl;

  FeesDatasource({
    required Dio http,
    String? baseUrl,
  })  : _http = http,
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
    // final halfHourFee = data['halfHourFee'] as int;
    // final hourFee = data['hourFee'] as int;
    final economyFee = data['economyFee'] as int;
    final minimumFee = data['minimumFee'] as int;

    final feeOptions = FeeOptions(
      fastest: MinerFee.relative(fastestFee.toDouble()),
      economic: MinerFee.relative(economyFee.toDouble()),
      slow: MinerFee.relative(minimumFee.toDouble()),
    );

    return feeOptions;
  }

  Future<FeeOptions> getLiquidNetworkFeeOptions({
    required bool isTestnet,
  }) async {
    const feeOptions = FeeOptions(
      fastest: MinerFee.relative(0.1),
      economic: MinerFee.relative(0.1),
      slow: MinerFee.relative(0.1),
    );

    return feeOptions;
  }
}
