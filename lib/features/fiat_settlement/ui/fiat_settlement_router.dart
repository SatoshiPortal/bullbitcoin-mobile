import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_routes.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/screens/fiat_settlement_editor_screen.dart';
import 'package:go_router/go_router.dart';

/// The shared per-product fiat-settlement editor route, pushed over a product
/// screen. `:product` is the product's wire id (lightning_address, payment_page,
/// pos, invoice); an unknown value falls back to the invoice product rather
/// than crashing the route.
class FiatSettlementRouter {
  const FiatSettlementRouter._();

  static final route = GoRoute(
    name: FiatSettlementRoute.fiatSettlementEditor.name,
    path: FiatSettlementRoute.fiatSettlementEditor.path,
    builder: (context, state) {
      final wire = state.pathParameters['product'];
      final product = FiatSettlementProduct.values.firstWhere(
        (p) => p.wire.wire == wire,
        orElse: () => FiatSettlementProduct.invoice,
      );
      // The `activated=1` variant is pushed right after an activation completes:
      // it adds a success header above the chooser. Absent (the entry-tile path)
      // the editor renders exactly as before.
      final activated = state.uri.queryParameters['activated'] == '1';
      return FiatSettlementEditorScreen(product: product, activated: activated);
    },
  );
}
