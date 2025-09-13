import 'package:bb_mobile/features/ledger/ledger_action.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:go_router/go_router.dart';

enum LedgerRoute {
  importLedger('/ledger-import'),
  signTransaction('/ledger-sign-transaction'),
  verifyAddress('/ledger-verify-address');

  final String path;

  const LedgerRoute(this.path);
}

class LedgerRouter {
  static final routes = [
    GoRoute(
      name: LedgerRoute.importLedger.name,
      path: LedgerRoute.importLedger.path,
      builder:
          (context, state) =>
              const LedgerActionScreen(action: LedgerAction.importWallet()),
    ),
    GoRoute(
      name: LedgerRoute.signTransaction.name,
      path: LedgerRoute.signTransaction.path,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return LedgerActionScreen(
          action: const LedgerAction.signTransaction(),
          parameters: extra,
        );
      },
    ),
    GoRoute(
      name: LedgerRoute.verifyAddress.name,
      path: LedgerRoute.verifyAddress.path,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return LedgerActionScreen(
          action: const LedgerAction.verifyAddress(),
          parameters: extra,
        );
      },
    ),
  ];
}
