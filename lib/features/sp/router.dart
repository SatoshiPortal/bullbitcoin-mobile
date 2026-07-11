import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_coins_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_receive_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_scan_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_amount_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_confirm_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_recipient_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_success_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_settings_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_setup_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_transaction_details_page.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_wallet_detail_page.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
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
String? spRedirect(
  String path, {
  required bool isSuperuser,
  required bool isDevModeEnabled,
  required bool isSpWalletSetup,
}) {
  if (!isSpPath(path)) return null;
  if (!isSuperuser || !isDevModeEnabled) return WalletRoute.walletHome.path;
  if (!isSpWalletSetup) return SpSetupRoute.spSetup.path;
  return null;
}

enum SpRoute {
  spWalletDetail('/sp-wallet-detail'),
  spSettings('/sp-settings'),
  spCoins('/sp-coins'),
  spTransactionDetails('/sp-transaction-details'),
  spReceive('/sp-receive'),
  spScan('/sp-scan'),
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
  static final route = GoRoute(
    name: SpSetupRoute.spSetup.name,
    path: SpSetupRoute.spSetup.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<SpSetupCubit>(),
      child: const SpSetupPage(),
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
        builder: (context, state) => const SpWalletDetailPage(),
      ),
      GoRoute(
        name: SpRoute.spSettings.name,
        path: SpRoute.spSettings.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<SpSettingsCubit>(),
          child: const SpSettingsPage(),
        ),
      ),
      GoRoute(
        name: SpRoute.spCoins.name,
        path: SpRoute.spCoins.path,
        builder: (context, state) => const SpCoinsPage(),
      ),
      GoRoute(
        name: SpRoute.spTransactionDetails.name,
        path: SpRoute.spTransactionDetails.path,
        builder: (context, state) {
          final payment = state.extra! as SpPayment;
          return SpTransactionDetailsPage(payment: payment);
        },
      ),
      GoRoute(
        name: SpRoute.spReceive.name,
        path: SpRoute.spReceive.path,
        builder: (context, state) => const SpReceivePage(),
      ),
      GoRoute(
        name: SpRoute.spScan.name,
        path: SpRoute.spScan.path,
        builder: (context, state) => const SpScanPage(),
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
    builder: (context, state, child) => BlocProvider(
      create: (_) => locator<SpSendCubit>(),
      child: child,
    ),
    routes: [
      GoRoute(
        name: SpRoute.spSendRecipient.name,
        path: SpRoute.spSendRecipient.path,
        builder: (context, state) => const SpSendRecipientPage(),
      ),
      GoRoute(
        name: SpRoute.spSendAmount.name,
        path: SpRoute.spSendAmount.path,
        builder: (context, state) => const SpSendAmountPage(),
      ),
      GoRoute(
        name: SpRoute.spSendConfirm.name,
        path: SpRoute.spSendConfirm.path,
        builder: (context, state) => const SpSendConfirmPage(),
      ),
      GoRoute(
        name: SpRoute.spSendSuccess.name,
        path: SpRoute.spSendSuccess.path,
        builder: (context, state) => const SpSendSuccessPage(),
      ),
    ],
  );
}
