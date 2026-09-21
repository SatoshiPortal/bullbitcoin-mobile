import 'package:flutter/widgets.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_recovery_notice_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_settings_screen.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_menu_screen.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_cosigner_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_cosigner_screen.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_onboarding_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_renewal_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_restore_screen.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract final class BullVaultRouter {
  static const scannerRouteName = 'bullVaultScanner';

  static List<GoRoute> routes({required String registerExternalRouteName}) => [
    menuRoute(registerExternalRouteName),
    route,
    scannerRoute,
    settingsRoute,
    policyRoute,
    keysRoute,
    renewRoute,
    cosignerRoute,
  ];

  static GoRoute menuRoute(String registerExternalRouteName) => GoRoute(
    name: BullVaultFacade.menuRouteName,
    path: '/bullvault',
    builder: (context, state) => BlocProvider(
      create: (_) => locator<BullVaultSettingsCubit>()..load(),
      child: BullVaultMenuScreen(
        registerExternalRouteName: registerExternalRouteName,
      ),
    ),
  );

  static final cosignerRoute = GoRoute(
    name: BullVaultFacade.cosignerRouteName,
    path: '/bullvault/:walletId/cosigner',
    builder: (context, state) => BlocProvider(
      create: (_) => locator<BullVaultCosignerCubit>(
        param1: state.pathParameters['walletId']!,
      ),
      child: const BullVaultCosignerScreen(),
    ),
  );

  static final route = GoRoute(
    name: BullVaultFacade.createRouteName,
    path: '/bullvault/create',
    builder: (context, state) => BlocProvider(
      create: (_) => locator<BullVaultOnboardingCubit>()
        ..load(
          walletId: state.uri.queryParameters['walletId'],
          practice: state.uri.queryParameters['practice'] == 'true',
        ),
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

  static Widget restoreView(
    BuildContext context, {
    ValueChanged<bool>? onRestoringChanged,
  }) => BlocProvider(
    create: (_) => locator<BullVaultRestoreCubit>(),
    child: BullVaultRestoreScreen(
      onRestoringChanged: onRestoringChanged,
      onRecovered: (result) => locator<BullVaultRecoveryNoticeCubit>().record(
        walletId: result.wallet.id,
        label: result.wallet.displayLabel(context),
      ),
    ),
  );

  static final settingsRoute = _inspectionRoute(
    BullVaultFacade.settingsRouteName,
    'settings',
    BullVaultSettingsPage.selected,
  );
  static final policyRoute = _inspectionRoute(
    BullVaultFacade.policyRouteName,
    'policy',
    BullVaultSettingsPage.policy,
  );
  static final keysRoute = _inspectionRoute(
    BullVaultFacade.keysRouteName,
    'keys',
    BullVaultSettingsPage.keys,
  );

  static GoRoute _inspectionRoute(
    String name,
    String path,
    BullVaultSettingsPage page,
  ) => GoRoute(
    name: name,
    path: '/bullvault/:walletId/$path',
    builder: (context, state) {
      final id = state.pathParameters['walletId']!;
      return BlocProvider(
        create: (_) => locator<BullVaultSettingsCubit>()..load(id),
        child: BullVaultSettingsScreen(walletId: id, page: page),
      );
    },
  );

  static final renewRoute = GoRoute(
    name: BullVaultFacade.renewRouteName,
    path: '/bullvault/:walletId/renew',
    builder: (context, state) {
      final walletId = state.pathParameters['walletId']!;
      return BlocProvider(
        create: (_) => locator<BullVaultRenewalCubit>(param1: walletId)..load(),
        child: BullVaultRenewalScreen(
          walletLabel:
              state.extra as String? ?? context.loc.bullVaultWalletLabel,
        ),
      );
    },
  );
}
