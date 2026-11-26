import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'bitbox_flow/bitbox_action.dart';
import 'bitbox_flow/bitbox_core_locator.dart';
import 'bitbox_flow/bitbox_locator.dart';
import 'bitbox_flow/ui/screens/bitbox_action_screen.dart';
import 'bitbox_routes.dart';
import 'ledger_flow/ledger_action.dart';
import 'ledger_flow/ledger_core_locator.dart' as core_ledger;
import 'ledger_flow/ledger_locator.dart' as flow_ledger;
import 'ledger_flow/ui/screens/ledger_action_screen.dart';
import 'ledger_routes.dart';
import 'psbt_flow/psbt_flow_locator.dart';
import 'psbt_flow/show_psbt/show_psbt_screen.dart';
import 'psbt_routes.dart';
import 'signer_device.dart';
import 'signers_l10n.dart';

final class SignersFeature {
  final List<GoRoute> routes;

  SignersFeature._(List<GoRoute> routes) : routes = List.unmodifiable(routes);

  /// Mounts the feature once in the foreground service registry.
  static SignersFeature mount({
    required GetIt services,
    required WriteSignerNfc writeNfc,
  }) {
    core_ledger.LedgerLocator.registerDatasources(services);
    core_ledger.LedgerLocator.registerRepositories(services);
    core_ledger.LedgerLocator.registerUsecases(services);
    BitBoxCoreLocator.registerDatasources(services);
    BitBoxCoreLocator.registerRepositories(services);
    BitBoxCoreLocator.registerUsecases(services);
    flow_ledger.LedgerLocator.setup(services);
    BitBoxLocator.setup(services);
    PsbtFlowLocator.setup(services);

    return SignersFeature._([
      GoRoute(
        name: PsbtFlowRoutes.show.name,
        path: PsbtFlowRoutes.show.path,
        builder: (context, state) {
          if (state.extra
              case (
                psbt: final String psbt,
                signerDevice: final SignerDevice? signerDevice,
              )
              when psbt.isNotEmpty) {
            return ShowPsbtScreen(
              services: services,
              psbt: psbt,
              signerDevice: signerDevice,
              writeNfc: writeNfc,
            );
          }
          return const _InvalidSignerRouteScreen();
        },
      ),
      for (final (route, action) in [
        (LedgerRoute.importLedger, const LedgerAction.importWallet()),
        (
          LedgerRoute.ledgerSignTransaction,
          const LedgerAction.signTransaction(),
        ),
        (LedgerRoute.ledgerVerifyAddress, const LedgerAction.verifyAddress()),
      ])
        GoRoute(
          name: route.name,
          path: route.path,
          builder: (context, state) {
            if (state.extra case final LedgerRouteParams parameters) {
              return LedgerActionScreen(
                services: services,
                action: action,
                parameters: parameters,
              );
            }
            return const _InvalidSignerRouteScreen();
          },
        ),
      for (final (route, action) in [
        (BitBoxRoute.importBitBox, const BitBoxAction.importWallet()),
        (
          BitBoxRoute.bitboxSignTransaction,
          const BitBoxAction.signTransaction(),
        ),
        (BitBoxRoute.bitboxVerifyAddress, const BitBoxAction.verifyAddress()),
      ])
        GoRoute(
          name: route.name,
          path: route.path,
          builder: (context, state) {
            if (state.extra case final BitBoxRouteParams parameters) {
              return BitBoxActionScreen(
                services: services,
                action: action,
                parameters: parameters,
              );
            }
            return const _InvalidSignerRouteScreen();
          },
        ),
    ]);
  }
}

class _InvalidSignerRouteScreen extends StatelessWidget {
  const _InvalidSignerRouteScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text(context.loc.oopsSomethingWentWrong)),
  );
}
