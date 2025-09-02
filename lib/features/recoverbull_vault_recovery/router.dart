import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/presentation/cubit.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/presentation/state.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/ui/recoverbull_vault_recovery_page.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum RecoverBullVaultRecovery {
  recoverbullVaultRecovery('/recoverbull/vault-recovery');

  final String path;

  const RecoverBullVaultRecovery(this.path);
}

class RecoverBullVaultRecoveryRouter {
  static final route = GoRoute(
    name: RecoverBullVaultRecovery.recoverbullVaultRecovery.name,
    path: RecoverBullVaultRecovery.recoverbullVaultRecovery.path,
    builder: (context, state) {
      final (backup: backup, backupKey: backupKey) =
          state.extra! as ({BullBackupEntity backup, String backupKey});

      return BlocProvider(
        create:
            (context) => RecoverBullVaultRecoveryCubit(
              backup: backup,
              backupKey: backupKey,
              decryptVaultUsecase: locator<DecryptVaultUsecase>(),
              restoreVaultUsecase: locator<RestoreVaultUsecase>(),
              checkWalletStatusUsecase: locator<TheDirtyUsecase>(),
            ),
        child: BlocListener<
          RecoverBullVaultRecoveryCubit,
          RecoverBullVaultRecoveryState
        >(
          listenWhen:
              (previous, current) => !previous.isImported && current.isImported,
          listener: (context, state) {
            // TODO(azad): something is missing from onboarding flow
            // TODO(azad): wallets are properly imported but does not appear on walletHome
            context.goNamed(WalletRoute.walletHome.name);
          },
          child: const RecoverBullVaultRecoveryPage(),
        ),
      );
    },
  );
}
