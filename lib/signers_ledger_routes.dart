import 'package:signers/routes.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

class LedgerRouter {
  static final routes = [
    for (final (route, action) in [
      (LedgerRoute.importLedger, const LedgerAction.importWallet()),
      (LedgerRoute.ledgerSignTransaction, const LedgerAction.signTransaction()),
      (LedgerRoute.ledgerVerifyAddress, const LedgerAction.verifyAddress()),
    ])
      GoRoute(
        name: route.name,
        path: route.path,
        builder: (context, state) {
          if (state.extra case final LedgerRouteParams parameters) {
            return LedgerActionScreen(action: action, parameters: parameters);
          }
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.loc.oopsSomethingWentWrong)),
          );
        },
      ),
  ];
}
