import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/flow.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum TestPhysicalBackupFlow { backup, verify }

enum TestWalletBackupRoute {
  testPhysicalBackupFlow('/test-physical-backup-flow');

  final String path;

  const TestWalletBackupRoute(this.path);
}

class TestWalletBackupRouter {
  static final route = GoRoute(
    name: TestWalletBackupRoute.testPhysicalBackupFlow.name,
    path: TestWalletBackupRoute.testPhysicalBackupFlow.path,
    builder: (context, state) {
      final flow =
          state.extra as TestPhysicalBackupFlow? ??
          TestPhysicalBackupFlow.backup;

      return BlocProvider(
        create: (context) => TestWalletBackupBloc(
          loadWalletsForNetworkUsecase: sl<LoadWalletsForNetworkUsecase>(),
          getMnemonicFromFingerprintUsecase:
              sl<GetMnemonicFromFingerprintUsecase>(),
          completePhysicalBackupVerificationUsecase:
              sl<CompletePhysicalBackupVerificationUsecase>(),
        )..add(const LoadWallets()),
        child: TestPhysicalBackupFlowNavigator(flow: flow),
      );
    },
  );
}
