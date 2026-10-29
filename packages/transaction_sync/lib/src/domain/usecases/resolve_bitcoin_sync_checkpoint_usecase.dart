import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../bitcoin_sync_checkpoint.dart';
import '../bitcoin_sync_script_type.dart';
import '../bitcoin_sync_checkpoint_resolver.dart';
import '../wallet_transaction_sync_failure.dart';

class ResolveBitcoinSyncCheckpointUsecase {
  const ResolveBitcoinSyncCheckpointUsecase();

  @useResult
  Result<BitcoinSyncCheckpoint, WalletTransactionSyncFailure> execute({
    required BitcoinNetwork network,
    DateTime? birthday,
    BitcoinSyncScriptType scriptType = BitcoinSyncScriptType.segwitV0,
    required DateTime now,
  }) => BitcoinSyncCheckpointResolver.resolve(
    network: network,
    birthday: birthday,
    scriptType: scriptType,
    now: now,
  );
}
