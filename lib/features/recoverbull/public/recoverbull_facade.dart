import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/check_recoverbull_backup_usecase.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class RecoverBullFacade {
  final CheckRecoverBullBackupUsecase _checkRecoverBullBackupUsecase;

  const RecoverBullFacade(CheckRecoverBullBackupUsecase usecase)
    : _checkRecoverBullBackupUsecase = usecase;

  Future<bool> hasTestedBackup(String fingerprint) =>
      _checkRecoverBullBackupUsecase.execute(fingerprint);

  static Future<bool> openSetup(
    BuildContext context, {
    required String seedFingerprint,
  }) async =>
      await context.pushNamed<bool>(
        RecoverBullRoute.recoverbullFlows.name,
        extra: RecoverBullFlowsExtra(
          flow: RecoverBullFlow.secureVault,
          vault: null,
          returnToCaller: true,
          seedFingerprint: seedFingerprint,
        ),
      ) ??
      false;

  static void openSettings(BuildContext context) => context.pushNamed(
    RecoverBullRoute.recoverbullFlows.name,
    extra: RecoverBullFlowsExtra(flow: RecoverBullFlow.settings, vault: null),
  );

  static Future<void> openViewVaultKey(BuildContext context) async {
    await context.pushNamed(
      RecoverBullRoute.recoverbullFlows.name,
      extra: RecoverBullFlowsExtra(
        flow: RecoverBullFlow.viewVaultKey,
        vault: null,
      ),
    );
  }
}
