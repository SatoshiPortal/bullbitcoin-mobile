import 'package:signers/routes.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

class BitBoxRouter {
  static final routes = [
    for (final (route, action) in [
      (BitBoxRoute.importBitBox, const BitBoxAction.importWallet()),
      (BitBoxRoute.bitboxSignTransaction, const BitBoxAction.signTransaction()),
      (BitBoxRoute.bitboxVerifyAddress, const BitBoxAction.verifyAddress()),
    ])
      GoRoute(
        name: route.name,
        path: route.path,
        builder: (context, state) {
          if (state.extra case final BitBoxRouteParams parameters) {
            return BitBoxActionScreen(action: action, parameters: parameters);
          }
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.loc.oopsSomethingWentWrong)),
          );
        },
      ),
  ];
}
