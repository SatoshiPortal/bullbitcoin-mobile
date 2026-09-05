import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_physical_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/flow.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum TestWalletBackupRoute {
  testPhysicalBackupFlow('/test-physical-backup-flow');

  final String path;

  const TestWalletBackupRoute(this.path);
}

class TestWalletBackupRouter {
  static final route = GoRoute(
    name: TestWalletBackupFacade.routeName,
    path: TestWalletBackupRoute.testPhysicalBackupFlow.path,
    builder: (context, state) {
      final extra = state.extra;
      final request = extra is VerifyPhysicalBackupRequest ? extra : null;
      final flow = switch (extra) {
        TestPhysicalBackupFlow value => value,
        VerifyPhysicalBackupRequest() => TestPhysicalBackupFlow.verify,
        _ => TestPhysicalBackupFlow.backup,
      };

      return BlocProvider(
        create: (context) => TestWalletBackupBloc(
          loadWalletsForNetworkUsecase: locator<LoadWalletsForNetworkUsecase>(),
          getMnemonicFromFingerprintUsecase:
              locator<GetMnemonicFromFingerprintUsecase>(),
          verifyPhysicalBackupUsecase: locator<VerifyPhysicalBackupUsecase>(),
          completePhysicalBackupVerificationUsecase:
              locator<CompletePhysicalBackupVerificationUsecase>(),
        )..add(LoadWallets(fingerprint: request?.fingerprint)),
        child: TestPhysicalBackupFlowNavigator(
          flow: flow,
          onVerified: request == null ? null : () => context.pop(true),
        ),
      );
    },
  );
}
