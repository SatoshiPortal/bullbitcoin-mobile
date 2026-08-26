import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'flow_type.dart';

enum RecoverBullRoute {
  recoverbullFlows('/recoverbull-flows'),
  recoverbullSecureVault('/recoverbull/secure'),
  recoverbullRecoverVault('/recoverbull/recover'),
  recoverbullTestVault('/recoverbull/test'),
  recoverbullViewVaultKey('/recoverbull/key'),
  recoverbullSettings('/recoverbull/settings');

  final String path;
  const RecoverBullRoute(this.path);
}

final class RecoverBullFlowsExtra {
  final RecoverBullFlow flow;
  final EncryptedVault? vault;

  const RecoverBullFlowsExtra({required this.flow, this.vault});
}

void openRecoverBullFlow(
  BuildContext context, {
  required RecoverBullFlow flow,
  EncryptedVault? vault,
}) => context.goNamed(
  RecoverBullRoute.recoverbullFlows.name,
  extra: RecoverBullFlowsExtra(flow: flow, vault: vault),
);
