import 'package:send/send.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    as wallet
    show Network, NetworkX;
import 'package:bull_logger/bull_logger.dart';
import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadSendNetworkFeesUsecase {
  final Fees _fees;

  const LoadSendNetworkFeesUsecase({required this._fees});

  @useResult
  Future<Result<FeeOptions, SendFailure>> execute({
    required wallet.Network walletNetwork,
    required bool isLiquid,
  }) async {
    final network = wallet.Network.fromEnvironment(
      environment: walletNetwork.environment,
      isLiquid: isLiquid,
    );
    return (await _fees.estimate(network.shared)).mapErr((failure) {
      log.warning('Network fee estimation unavailable: ${failure.runtimeType}');
      return SendFeesUnavailableFailure(failure.runtimeType.toString());
    });
  }
}
