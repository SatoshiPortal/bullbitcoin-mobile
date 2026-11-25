import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/sp_failure_mapping.dart';
import 'package:silent/silent.dart';
import 'package:primitives/primitives.dart';

class GetSpNetworkForSendUsecase {
  final Silent _silent;

  GetSpNetworkForSendUsecase(this._silent);

  /// The network the SP wallet runs on, in the [BitcoinNetwork] the send screens
  /// speak. Never guesses: no live session to ask is an `Err` like a failed
  /// read, so a caller can fail closed instead of assuming mainnet.
  Future<Result<BitcoinNetwork, SendFailure>> execute() async =>
      (await _silent.network()).fold(
        (network) => switch (network) {
          BitcoinNetwork.mainnet => const Ok(BitcoinNetwork.mainnet),
          BitcoinNetwork.testnet => const Ok(BitcoinNetwork.testnet),
          BitcoinNetwork.signet || BitcoinNetwork.regtest => const Err(
            SendUnexpectedFailure('unsupported network'),
          ),
          null => const Err(
            SendUnexpectedFailure(
              'no live SP session to read the network from',
            ),
          ),
        },
        (failure) => Err(
          failure.toSendFailure() ?? SendUnexpectedFailure(failure.logMessage),
        ),
      );
}
