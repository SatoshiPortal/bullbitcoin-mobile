import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_onboarding_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_restore_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_scanner_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract final class BullVaultRouter {
  static const scannerRouteName = 'bullVaultScanner';

  static final routes = [route, scannerRoute, restoreRoute];

  static final route = GoRoute(
    name: BullVaultFacade.createRouteName,
    path: '/bullvault/create',
    builder: (context, state) => BlocProvider(
      create: (_) =>
          locator<BullVaultOnboardingCubit>()
            ..load(walletId: state.uri.queryParameters['walletId']),
      child: const BullVaultOnboardingScreen(),
    ),
  );

  static final scannerRoute = GoRoute(
    name: scannerRouteName,
    path: '/bullvault/scan',
    builder: (context, state) => BullVaultScannerScreen(
      purpose: switch (state.extra) {
        final BullVaultScannerPurpose purpose => purpose,
        _ => BullVaultScannerPurpose.publicAccountKey,
      },
    ),
  );

  static final restoreRoute = GoRoute(
    name: BullVaultFacade.restoreRouteName,
    path: '/bullvault/restore',
    builder: (context, state) => BlocProvider(
      create: (_) => locator<BullVaultRestoreCubit>(),
      child: const BullVaultRestoreScreen(),
    ),
  );
}
