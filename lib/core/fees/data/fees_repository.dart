import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

abstract class FeesRepository {
  /// Get Bitcoin network fee options
  Future<FeeOptions> getBitcoinNetworkFees({required bool isTestnet});

  /// Get Liquid network fee options
  Future<FeeOptions> getLiquidNetworkFees({required bool isTestnet});
}

class FeesRepositoryImpl implements FeesRepository {
  final FeesDatasource _feesDatasource;

  const FeesRepositoryImpl({
    required FeesDatasource feesDatasource,
  }) : _feesDatasource = feesDatasource;

  @override
  Future<FeeOptions> getBitcoinNetworkFees({required bool isTestnet}) async {
    final feeOptions = await _feesDatasource.getBitcoinNetworkFeeOptions(
      isTestnet: isTestnet,
    );
    return feeOptions;
  }

  @override
  Future<FeeOptions> getLiquidNetworkFees({required bool isTestnet}) async {
    final feeOptions = await _feesDatasource.getLiquidNetworkFeeOptions(
      isTestnet: isTestnet,
    );
    return feeOptions;
  }

  /// Helper method to get appropriate fees based on network
  Future<FeeOptions> getNetworkFees({required Network network}) async {
    if (network.isLiquid) {
      return getLiquidNetworkFees(isTestnet: network.isTestnet);
    } else {
      return getBitcoinNetworkFees(isTestnet: network.isTestnet);
    }
  }
}
