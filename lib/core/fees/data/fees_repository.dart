import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class FeesRepository {
  final FeesDatasource _feesDatasource;

  const FeesRepository({
    required FeesDatasource feesDatasource,
  }) : _feesDatasource = feesDatasource;

  Future<FeeOptions> getNetworkFees({required Network network}) async {
    FeeOptions feeOptions;

    if (network.isBitcoin) {
      feeOptions = await _feesDatasource.getBitcoinNetworkFeeOptions(
        isTestnet: network.isTestnet,
      );
    } else {
      feeOptions = await _feesDatasource.getLiquidNetworkFeeOptions(
        isTestnet: network.isTestnet,
      );
    }

    return feeOptions;
  }
}
