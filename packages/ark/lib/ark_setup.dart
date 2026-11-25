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
import 'src/data/scuttle_native_opener.dart';

/// Scuttle smoke uses explicit, reviewed reserve funding only.
const scuttleRegtestSmoke =
    !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile') &&
    bool.fromEnvironment('BULL_ARK_SCUTTLE_SMOKE');

ArkClient createArkClient({
  required String storagePath,
  required ArkChildProviderPort childProvider,
  required ArkTransactionVerifierPort transactionVerifier,
  required ArkExecutionPolicyPort executionPolicy,
  ArkBoardAbandonmentPort? boardAbandonment,
  ArkExecutionMode executionMode = ArkExecutionMode.foreground,
  ArkStageBudget stageBudget = const ArkUnlimitedStageBudget(),
}) => BarkArkClient(
  storagePath: scuttleRegtestSmoke ? '$storagePath/scuttle-smoke' : storagePath,
  childProvider: childProvider,
  transactionVerifier: transactionVerifier,
  executionPolicy: executionPolicy,
  boardAbandonment: boardAbandonment,
  executionMode: executionMode,
  stageBudget: stageBudget,
  opener: scuttleRegtestSmoke
      ? const ScuttleNativeOpener()
      : const BarkNativeOpener(),
  nativeVersion: scuttleRegtestSmoke
      ? 'scuttle-2ad259dc-smoke'
      : '0.27.0+bark-0.8.1',
  preflight: const HttpArkChainPreflight(),
);
