import 'package:bb_mobile/features/ledger/ledger_action.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:go_router/go_router.dart';

enum LedgerRoute {
  importLedger('/ledger-import'),
  ledgerSignTransaction('/ledger-sign-transaction'),
  ledgerVerifyAddress('/ledger-verify-address');

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
      name: LedgerRoute.ledgerSignTransaction.name,
      path: LedgerRoute.ledgerSignTransaction.path,
      builder: (context, state) {
        final extra = state.extra as LedgerRouteParams?;
        return LedgerActionScreen(
          action: const LedgerAction.signTransaction(),
          parameters: extra,
        );
      },
    ),
    GoRoute(
      name: LedgerRoute.ledgerVerifyAddress.name,
      path: LedgerRoute.ledgerVerifyAddress.path,
      builder: (context, state) {
        final extra = state.extra as LedgerRouteParams?;
        return LedgerActionScreen(
          action: const LedgerAction.verifyAddress(),
          parameters: extra,
        );
      },
    ),
  ];
}
