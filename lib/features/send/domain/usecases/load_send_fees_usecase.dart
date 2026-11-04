import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';

typedef SendFeeRates = ({
  FeeOptions bitcoin,
  FeeOptions liquid,
  bool usingFallbackBitcoinFees,
});

/// Loads the two fee sets required by the send flow while keeping chain-specific
/// fallback policy out of presentation state management.
class LoadSendFeesUsecase {
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;

  const LoadSendFeesUsecase(this._getNetworkFeesUsecase);

  Future<Result<SendFeeRates, SendFailure>> execute({
    FeeOptions? previousBitcoinFees,
    FeeOptions? previousLiquidFees,
  }) async {
    FeeOptions liquidFees;
    try {
      liquidFees = await _getNetworkFeesUsecase.execute(isLiquid: true);
    } on GetNetworkFeesException catch (error, stackTrace) {
      if (previousLiquidFees == null) {
        return Err(SendFeesUnavailableFailure(error.toString()));
      }
      log.warning(
        'Using previously loaded Liquid fee rates',
        error: error,
        trace: stackTrace,
      );
      liquidFees = previousLiquidFees;
    }

    try {
      final bitcoinFees = await _getNetworkFeesUsecase.execute(isLiquid: false);
      return Ok((
        bitcoin: bitcoinFees,
        liquid: liquidFees,
        usingFallbackBitcoinFees: false,
      ));
    } on GetNetworkFeesException catch (error, stackTrace) {
      log.warning(
        'Using fallback Bitcoin fee rates',
        error: error,
        trace: stackTrace,
      );
      return Ok((
        bitcoin: previousBitcoinFees ?? _buildFallbackBitcoinFees(),
        liquid: liquidFees,
        usingFallbackBitcoinFees: true,
      ));
    }
  }

  FeeOptions _buildFallbackBitcoinFees() => FeeOptions(
    fastest: NetworkFee.relativeFromSatPerVbyte(1),
    economic: NetworkFee.relativeFromSatPerVbyte(1),
    slow: NetworkFee.relativeFromSatPerVbyte(1),
    minRelay: NetworkFee.relativeFromSatPerVbyte(
      NetworkFeeRelayPolicy.minRelaySatPerVbyte,
    ),
  );
}
