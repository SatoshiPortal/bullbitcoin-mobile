import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/mappers/mempool_fees_mapper.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class FeesRepositoryImpl implements FeesRepository {
  final FeesDatasource _feesDatasource;

  const FeesRepositoryImpl({required this._feesDatasource});

  @override
  Future<FeeOptions> getNetworkFees({required Network network}) async {
    if (network.isBitcoin) {
      final fees = await _feesDatasource.fetchBitcoinNetworkFees(
        isTestnet: network.isTestnet,
      );
      return MempoolFeesMapper.toFeeOptions(fees);
    }

    // Liquid blocks are typically empty, so the network's minrelayfee
    // (0.1 sat/vByte = 25 sat/kwu) is the only relevant fee tier today.
    // The three presets are kept identical for UI parity with Bitcoin.
    const minRelay = RelativeFee(NetworkFeeRelayPolicy.minRelaySatPerKwu);
    return const FeeOptions(
      fastest: minRelay,
      economic: minRelay,
      slow: minRelay,
      minRelay: minRelay,
    );
  }
}
