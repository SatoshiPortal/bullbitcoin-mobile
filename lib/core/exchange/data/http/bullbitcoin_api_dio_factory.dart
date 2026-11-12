import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';

class BullBitcoinApiDioFactory {
  static Dio create({required bool isTestnet}) {
    return isTestnet ? _buildBullbitcoinTestnetDio() : _buildBullbitcoinDio();
  }

  static Dio _buildBullbitcoinDio() =>
      Dio(BaseOptions(baseUrl: ApiServiceConstants.bbApiUrl));

  static Dio _buildBullbitcoinTestnetDio() =>
      Dio(BaseOptions(baseUrl: ApiServiceConstants.bbApiTestUrl));
}
