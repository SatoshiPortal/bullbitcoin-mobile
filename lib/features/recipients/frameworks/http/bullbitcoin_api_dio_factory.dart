import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:dio/dio.dart';

// TODO: This should be moved to the core/shared folder since more features
//  will need to call the Bull Bitcoin API.
class BullBitcoinApiDioFactory {
  static Dio create({required bool isTestnet}) {
    return isTestnet ? _buildBullbitcoinTestnetDio() : _buildBullbitcoinDio();
  }

  static Dio _buildBullbitcoinDio() =>
      Dio(BaseOptions(baseUrl: ApiServiceConstants.bbApiUrl));

  static Dio _buildBullbitcoinTestnetDio() =>
      Dio(BaseOptions(baseUrl: ApiServiceConstants.bbApiTestUrl));
}
