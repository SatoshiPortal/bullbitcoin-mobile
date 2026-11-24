import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:send/send.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:silent/silent.dart';
import 'package:primitives/primitives.dart' hide Network;

export 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;

class GetSpNetworkForSendUsecase {
  final Silent _silent;

  GetSpNetworkForSendUsecase(this._silent);

  /// The network the SP wallet runs on, in the [Network] the send screens
  /// speak. Never guesses: no live session to ask is an `Err` like a failed
  /// read, so a caller can fail closed instead of assuming mainnet.
  Future<Result<Network, SendFailure>> execute() async =>
      (await _silent.network()).fold(
        (network) => switch (network) {
          BitcoinNetwork.mainnet => const Ok(Network.bitcoinMainnet),
          BitcoinNetwork.testnet => const Ok(Network.bitcoinTestnet),
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
