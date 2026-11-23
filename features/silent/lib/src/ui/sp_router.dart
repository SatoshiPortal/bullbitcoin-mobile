import 'package:primitives/primitives.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
import 'package:silent/src/presentation/sp_settings_cubit.dart';
import 'package:silent/src/presentation/sp_setup_cubit.dart';
import 'package:silent/src/ui/screens/sp_coins_screen.dart';
import 'package:silent/src/ui/screens/sp_header_validation_screen.dart';
import 'package:silent/src/ui/screens/sp_receive_screen.dart';
import 'package:silent/src/ui/screens/sp_scan_screen.dart';
import 'package:silent/src/ui/screens/sp_settings_screen.dart';
import 'package:silent/src/ui/screens/sp_setup_screen.dart';
import 'package:silent/src/ui/screens/sp_transaction_details_screen.dart';
import 'package:silent/src/ui/screens/sp_wallet_detail_screen.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// True when [path] targets an SP route (exact match or a nested sub-path).
bool isSpPath(String path) => [
  ...SpRoute.values.map((r) => r.path),
  ...SpSetupRoute.values.map((r) => r.path),
].any((route) => path == route || path.startsWith('$route/'));

/// Pure SP route gate, extracted so it is unit-testable with no widget tree.
///
/// SP is gated behind superuser + dev mode; this re-checks on every navigation
/// because `WalletBloc.state.isSpWalletSetup` can stay stale for a beat after
/// dev mode is toggled off. Returns the path to redirect to, or null to allow
/// the navigation. Non-SP paths always return null.
///
/// [gateClosedRedirectPath] is the destination when the superuser/dev-mode gate
/// is closed; the composition root supplies it (the wallet home) so this pure
/// gate never imports the wallet feature's router.
String? spRedirect(
  String path, {
  required NetworkEnv? environment,
  required bool isSuperuser,
  required bool isDevModeEnabled,
  required bool isSpWalletSetup,
  required String gateClosedRedirectPath,
}) {
  if (!isSpPath(path)) return null;
  if (environment == null ||
      !NetworkCapabilities.supports(
        BitcoinNetwork.values.firstWhere(
          (network) => network.env == environment,
        ),
        NetworkCapability.silentPayments,
      ) ||
      !isSuperuser ||
      !isDevModeEnabled) {
    return gateClosedRedirectPath;
  }
  if (!isSpWalletSetup && path != SpSetupRoute.spSetup.path) {
    return SpSetupRoute.spSetup.path;
  }
  return null;
}

/// Fallback path for the SP transaction-details route when navigated without a
/// valid [SpPayment] in `state.extra` (e.g. a deep link or a stale restore).
/// Returns the SP coins path to redirect to, or null to allow the navigation.
/// Extracted so it is unit-testable with no widget tree.
String? spTransactionDetailsRedirect(Object? extra) =>
    extra is SpPayment ? null : SpRoute.spCoins.path;

enum SpRoute {
  spWalletDetail('/sp-wallet-detail'),
  spSettings('/sp-settings'),
  spCoins('/sp-coins'),
  spTransactionDetails('/sp-transaction-details'),
  spReceive('/sp-receive'),
  spScan('/sp-scan'),
  spHeaderValidation('/sp-header-validation');

  final String path;
  const SpRoute(this.path);
}

enum SpSetupRoute {
  spSetup('/sp-setup');

  final String path;
  const SpSetupRoute(this.path);
}

class SpSetupRouter {
  static GoRoute route({
    required String successRedirectPath,
    required SpSetupCubit Function() createSetupCubit,
  }) => GoRoute(
    name: SpSetupRoute.spSetup.name,
    path: SpSetupRoute.spSetup.path,
    builder: (context, state) => BlocProvider(
      create: (_) => createSetupCubit(),
      child: SpSetupScreen(successRedirectPath: successRedirectPath),
    ),
  );
}

class SpRouter {
  static ShellRoute route({
    required SpCubit Function() createCubit,
    required SpSettingsCubit Function() createSettingsCubit,
    required void Function(BuildContext) openSend,
    required String exitRedirectPath,
    required Widget Function(BuildContext, int) balanceBuilder,
    required Widget Function(BuildContext) settingsIconBuilder,
  }) => ShellRoute(
    builder: (context, state, child) {
      // The SP session lives in the SpAccountRepository (lazySingleton); the
      // top-level GoRouter redirect already gates entry on
      // superuser + dev-mode + isSpWalletSetup, so we just provide the cubit.
      return BlocProvider(
        create: (context) => createCubit()..load(),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: SpRoute.spWalletDetail.name,
        path: SpRoute.spWalletDetail.path,
        builder: (context, state) => SpWalletDetailScreen(
          exitRedirectPath: exitRedirectPath,
          balanceBuilder: balanceBuilder,
          settingsIconBuilder: settingsIconBuilder,
          onSend: () => openSend(context),
        ),
      ),
      GoRoute(
        name: SpRoute.spSettings.name,
        path: SpRoute.spSettings.path,
        builder: (context, state) => BlocProvider(
          create: (_) => createSettingsCubit(),
          child: SpSettingsScreen(exitRedirectPath: exitRedirectPath),
        ),
      ),
      GoRoute(
        name: SpRoute.spCoins.name,
        path: SpRoute.spCoins.path,
        builder: (context, state) => const SpCoinsScreen(),
      ),
      GoRoute(
        name: SpRoute.spTransactionDetails.name,
        path: SpRoute.spTransactionDetails.path,
        redirect: (context, state) => spTransactionDetailsRedirect(state.extra),
        builder: (context, state) => switch (state.extra) {
          final SpPayment payment => SpTransactionDetailsScreen(
            payment: payment,
          ),
          _ => const SpCoinsScreen(),
        },
      ),
      GoRoute(
        name: SpRoute.spReceive.name,
        path: SpRoute.spReceive.path,
        builder: (context, state) => const SpReceiveScreen(),
      ),
      GoRoute(
        name: SpRoute.spScan.name,
        path: SpRoute.spScan.path,
        builder: (context, state) => const SpScanScreen(),
      ),
      GoRoute(
        name: SpRoute.spHeaderValidation.name,
        path: SpRoute.spHeaderValidation.path,
        builder: (context, state) => const SpHeaderValidationScreen(),
      ),
    ],
  );
}
