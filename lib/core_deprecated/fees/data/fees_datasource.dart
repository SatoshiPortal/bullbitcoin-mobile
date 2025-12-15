import 'package:bb_mobile/core_deprecated/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:dio/dio.dart';

class FeesDatasource {
  final Dio _bitcoinMainnetMempoolHttpClient;
  final Dio _bitcoinTestnetMempoolHttpClient;

  FeesDatasource({
    String? bitcoinMainnetMempoolUrl,
    String? bitcoinTestnetMempoolUrl,
  }) : _bitcoinMainnetMempoolHttpClient = Dio(
         BaseOptions(
           baseUrl:
               bitcoinMainnetMempoolUrl ??
               'https://${ApiServiceConstants.bbMempoolUrlPath}',
         ),
       ),
       _bitcoinTestnetMempoolHttpClient = Dio(
         BaseOptions(
           baseUrl:
               bitcoinTestnetMempoolUrl ??
               'https://${ApiServiceConstants.testnetMempoolUrlPath}',
         ),
       );

  Future<FeeOptions> getBitcoinNetworkFeeOptions({
    required bool isTestnet,
  }) async {
    final http =
        isTestnet
            ? _bitcoinTestnetMempoolHttpClient
            : _bitcoinMainnetMempoolHttpClient;
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
