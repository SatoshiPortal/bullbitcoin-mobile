import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' show Network;

class GetSpNetworkForSendUsecase {
  final SpFacade _spFacade;

  GetSpNetworkForSendUsecase(this._spFacade);

  /// The network the SP wallet runs on, in the [Network] the send screens
  /// speak. Never guesses: no live session to ask is an `Err` like a failed
  /// read, so a caller can fail closed instead of assuming mainnet.
  Result<Network, SendFailure> execute() => _spFacade.network().fold(
    (network) => switch (network) {
      BitcoinNetwork.mainnet => const Ok(Network.bitcoinMainnet),
      BitcoinNetwork.testnet ||
      BitcoinNetwork.signet ||
      BitcoinNetwork.regtest => const Ok(Network.bitcoinTestnet),
      null => const Err(
        SendUnexpectedFailure('no live SP session to read the network from'),
      ),
    },
    (failure) => Err(
      failure.toSendFailure() ?? SendUnexpectedFailure(failure.logMessage),
    ),
  );
}
