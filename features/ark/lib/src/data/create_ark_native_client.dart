import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' as native;

import 'ark_network_execution_policy.dart';

/// Required host authority and budget are retained in both execution modes.
ArkClient createArkNativeClient({
  required String storagePath,
  required native.ArkChildProviderPort childProvider,
  required ArkTransactionVerifierPort transactionVerifier,
  required native.ArkExecutionPolicyPort executionPolicy,
  required native.ArkExecutionMode executionMode,
  required native.ArkStageBudget stageBudget,
  native.ArkBoardAbandonmentPort? boardAbandonment,
}) => native.createArkClient(
  storagePath: storagePath,
  childProvider: childProvider,
  transactionVerifier: transactionVerifier,
  executionPolicy: ArkNetworkExecutionPolicy(executionPolicy),
  executionMode: executionMode,
  stageBudget: stageBudget,
  boardAbandonment: boardAbandonment,
);
