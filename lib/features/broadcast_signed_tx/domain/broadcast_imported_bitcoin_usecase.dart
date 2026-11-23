import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

class BroadcastImportedBitcoinUsecase {
  final Spend _spend;
  final ActiveEnvironmentReader _environment;

  const BroadcastImportedBitcoinUsecase(this._spend, this._environment);

  Future<BitcoinNetwork?> captureNetwork() async =>
      switch (await _environment.readActiveEnvironment()) {
        Ok(:final value) => switch (value.networkEnv) {
          NetworkEnv.mainnet => BitcoinNetwork.mainnet,
          NetworkEnv.testnet => BitcoinNetwork.testnet,
          NetworkEnv.regtest => BitcoinNetwork.regtest,
          NetworkEnv.signet => null,
        },
        Err() => null,
      };

  @useResult
  Future<Result<String, BroadcastSignedTxFailure>> execute({
    required String transaction,
    required bool isPsbt,
    required BitcoinNetwork? network,
  }) async {
    if (network == null) {
      return const Err(BroadcastNetworkNotEnabledFailure());
    }
    return (await _spend.broadcastImportedBitcoin(
      transaction: transaction,
      isPsbt: isPsbt,
      network: network,
    )).mapErr(
      (failure) => switch (failure) {
        SpendBroadcastConnectionFailure() => const BroadcastFailedFailure(),
        SpendAlreadyInChainFailure() =>
          const TransactionAlreadyInChainFailure(),
        SpendBroadcastRejectedFailure() ||
        SpendSelectedInputsUnavailableFailure() =>
          const TransactionRejectedFailure(),
        SpendDeveloperAuthorizationFailure() || SpendNetworkMismatchFailure() =>
          const BroadcastNetworkNotEnabledFailure(),
        SpendInvalidTransactionFailure() => const InvalidTransactionFailure(),
        SpendBroadcastOutcomeUnknownFailure() =>
          const BroadcastOutcomeUnknownFailure(),
        _ => const BroadcastUnexpectedFailure(),
      },
    );
  }
}
