import 'package:send/src/payment/domain/send_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadSendNetworkFeesUsecase {
  final Fees _fees;

  const LoadSendNetworkFeesUsecase({required this._fees});

  @useResult
  Future<Result<FeeOptions, SendFailure>> execute({
    required Network walletNetwork,
    required bool isLiquid,
  }) async {
    final Network network;
    switch ((walletNetwork.env, isLiquid)) {
      case (NetworkEnv.mainnet, true):
        network = LiquidNetwork.mainnet;
      case (NetworkEnv.testnet, true):
        network = LiquidNetwork.testnet;
      case (NetworkEnv.regtest, true):
        network = LiquidNetwork.regtest;
      case (NetworkEnv.mainnet, false):
        network = BitcoinNetwork.mainnet;
      case (NetworkEnv.testnet, false):
        network = BitcoinNetwork.testnet;
      case (NetworkEnv.regtest, false):
        network = BitcoinNetwork.regtest;
      case (NetworkEnv.signet, _):
        return const Err(SendFeesUnavailableFailure('Unsupported network'));
    }
    return (await _fees.estimate(network)).mapErr((failure) {
      log.warning('Network fee estimation unavailable: ${failure.runtimeType}');
      return SendFeesUnavailableFailure(failure.runtimeType.toString());
    });
  }
}
