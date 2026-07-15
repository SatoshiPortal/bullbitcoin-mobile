import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_coins_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_header_validation_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_receive_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_scan_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_amount_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_confirm_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_recipient_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_success_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_settings_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_setup_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_transaction_details_screen.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_wallet_detail_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// True when [path] targets an SP route (exact match or a nested sub-path).
bool isSpPath(String path) =>
    SpRoute.values.any((r) => path == r.path || path.startsWith('${r.path}/'));

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
  required bool isSuperuser,
  required bool isDevModeEnabled,
  required bool isSpWalletSetup,
  required String gateClosedRedirectPath,
}) {
  if (!isSpPath(path)) return null;
  if (!isSuperuser || !isDevModeEnabled) return gateClosedRedirectPath;
  if (!isSpWalletSetup) return SpSetupRoute.spSetup.path;
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
  spHeaderValidation('/sp-header-validation'),
  spSendRecipient('/sp-send'),
  spSendAmount('/sp-send/amount'),
  spSendConfirm('/sp-send/confirm'),
  spSendSuccess('/sp-send/success');

  final String path;
  const SpRoute(this.path);
}

enum SpSetupRoute {
  spSetup('/sp-setup');

  final String path;
  const SpSetupRoute(this.path);
}

class SpSetupRouter {
  static GoRoute route({required String successRedirectPath}) => GoRoute(
    name: SpSetupRoute.spSetup.name,
    path: SpSetupRoute.spSetup.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<SpSetupCubit>(),
      child: SpSetupScreen(successRedirectPath: successRedirectPath),
    ),
  );
}

class SpRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      // The SP session lives in the SpAccountRepository (lazySingleton); the
      // top-level GoRouter redirect already gates entry on
      // superuser + dev-mode + isSpWalletSetup, so we just provide the cubit.
      return BlocProvider(
        create: (context) => locator<SpCubit>()..load(),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: SpRoute.spWalletDetail.name,
        path: SpRoute.spWalletDetail.path,
        builder: (context, state) => const SpWalletDetailScreen(),
      ),
      GoRoute(
        name: SpRoute.spSettings.name,
        path: SpRoute.spSettings.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<SpSettingsCubit>(),
          child: const SpSettingsScreen(),
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
        builder: (context, state) {
          final payment = state.extra! as SpPayment;
          return SpTransactionDetailsScreen(payment: payment);
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
      _sendRoute,
    ],
  );

  // The send flow (recipient -> amount -> confirm -> success) is scoped to its
  // own SpSendCubit, provided once for the whole sub-tree so state carries
  // across pages. Navigation is imperative (pushNamed from the button handlers
  // after each action succeeds), not driven by state edges. A fresh cubit per
  // entry means a stale recipient/amount/simulation can never wedge re-entry.
  static final _sendRoute = ShellRoute(
    builder: (context, state, child) =>
        BlocProvider(create: (_) => locator<SpSendCubit>(), child: child),
    routes: [
      GoRoute(
        name: SpRoute.spSendRecipient.name,
        path: SpRoute.spSendRecipient.path,
        builder: (context, state) => const SpSendRecipientScreen(),
      ),
      GoRoute(
        name: SpRoute.spSendAmount.name,
        path: SpRoute.spSendAmount.path,
        builder: (context, state) => const SpSendAmountScreen(),
      ),
      GoRoute(
        name: SpRoute.spSendConfirm.name,
        path: SpRoute.spSendConfirm.path,
        builder: (context, state) => const SpSendConfirmScreen(),
      ),
      GoRoute(
        name: SpRoute.spSendSuccess.name,
        path: SpRoute.spSendSuccess.path,
        builder: (context, state) => const SpSendSuccessScreen(),
      ),
    ],
  );
}
