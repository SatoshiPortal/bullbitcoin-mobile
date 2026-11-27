import 'package:primitives/primitives.dart';

import '../domain/recoverbull_failure.dart';
import '../domain/usecases/run_passkey_demo_usecase.dart';
import 'vault_flow_cubit.dart';
import 'backup_monitoring_cubit.dart';

final class VaultFlowPresentation {
  final VaultFlowCubit cubit;
  final Result<BitcoinNetwork, RecoverBullFailure> network;
  final BackupMonitoringCubit? monitoring;
  final bool defaultHasPassphrase;
  final RunPasskeyDemoUsecase? passkeyDemo;
  const VaultFlowPresentation(
    this.cubit,
    this.network,
    this.monitoring, {
    this.defaultHasPassphrase = false,
    this.passkeyDemo,
  });

  Future<void> close() async {
    await cubit.close();
    await monitoring?.close();
  }
}
