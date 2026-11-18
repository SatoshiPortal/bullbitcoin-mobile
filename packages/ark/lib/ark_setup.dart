/// Privileged composition surface; never re-export from the feature facade.
library;

export 'src/domain/ark_execution_policy.dart';
export 'src/domain/ark_board_abandonment_port.dart';

import 'ark.dart';
import 'src/domain/ark_execution_policy.dart';
import 'src/domain/ark_board_abandonment_port.dart';
import 'src/data/bark_ark_client.dart';
import 'src/data/bark_native_opener.dart';
import 'src/data/ark_chain_preflight.dart';

ArkClient createArkClient({
  required String storagePath,
  required ArkChildProviderPort childProvider,
  required ArkTransactionVerifierPort transactionVerifier,
  required ArkExecutionPolicyPort executionPolicy,
  ArkBoardAbandonmentPort? boardAbandonment,
  ArkExecutionMode executionMode = ArkExecutionMode.foreground,
  ArkStageBudget stageBudget = const ArkUnlimitedStageBudget(),
}) => BarkArkClient(
  storagePath: storagePath,
  childProvider: childProvider,
  transactionVerifier: transactionVerifier,
  executionPolicy: executionPolicy,
  boardAbandonment: boardAbandonment,
  executionMode: executionMode,
  stageBudget: stageBudget,
  opener: const BarkNativeOpener(),
  preflight: const HttpArkChainPreflight(),
);
