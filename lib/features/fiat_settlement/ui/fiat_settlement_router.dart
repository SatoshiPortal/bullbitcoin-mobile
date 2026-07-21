import 'package:bb_mobile/core/screens/route_error_screen.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_routes.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/screens/fiat_settlement_editor_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

/// The shared per-product fiat-settlement editor route, pushed over a product
/// screen. `:product` is the product's wire id (lightning_address, payment_page,
/// pos, invoice).
///
/// Route boundary (owner decision D2): the ONLY things rejected here are an
/// unknown product and a non-mainnet environment. An unknown product uses the
/// app's established invalid-route surface (never a silent fallback to another
/// product); a non-mainnet environment is dismissed back to the wallet home
/// (defence in depth — the entry points are already mainnet-only). Account,
/// eligibility, and configuration problems are editor states, not route gates.
class FiatSettlementRouter {
  const FiatSettlementRouter._();

  static final route = GoRoute(
    name: FiatSettlementRoute.fiatSettlementEditor.name,
    path: FiatSettlementRoute.fiatSettlementEditor.path,
    redirect: (context, state) async {
      if (!locator.isRegistered<GetSettingsUsecase>()) return null;
      final settings = await locator<GetSettingsUsecase>().execute();
      if (settings.environment != Environment.mainnet) {
        return WalletRoute.walletHome.path;
      }
      return null;
    },
    builder: (context, state) {
      final wire = state.pathParameters['product'];
      final product = _productForWire(wire);
      if (product == null) return const RouteErrorScreen();
      // The `activated=1` variant is pushed right after an activation completes:
      // it adds a success header above the chooser. Absent (the entry-tile path)
      // the editor renders exactly as before.
      final activated = state.uri.queryParameters['activated'] == '1';
      return FiatSettlementEditorScreen(product: product, activated: activated);
    },
  );

  static FiatSettlementProduct? _productForWire(String? wire) {
    for (final product in FiatSettlementProduct.values) {
      if (product.pathId == wire) return product;
    }
    return null;
  }
}
