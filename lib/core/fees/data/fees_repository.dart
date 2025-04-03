import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class FeesRepository {
  final FeesDatasource _feesDatasource;

  const FeesRepository({
    required FeesDatasource feesDatasource,
  }) : _feesDatasource = feesDatasource;

  Future<FeeOptions> getNetworkFees({required Network network}) async {
    if (network.isBitcoin) {
      return _feesDatasource.getBitcoinNetworkFeeOptions(
        isTestnet: network.isTestnet,
      );
    } else {
      return _feesDatasource.getLiquidNetworkFeeOptions(
        isTestnet: network.isTestnet,
      );
    }
  }
}
