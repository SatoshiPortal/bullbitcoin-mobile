import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_routes.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Offers the fiat-settlement chooser immediately after a Get Paid product's
/// activation succeeds, by pushing the shared editor in its "activated" variant
/// (a success header above the "How do you want to receive the funds?" chooser,
/// with Bitcoin shown as the currently-active choice).
///
/// Gated identically to [FiatSettlementEntryTile]: locator-only reads, and only
/// on mainnet with the facade registered. On testnet or when the feature is not
/// registered it does nothing, so the activation flow stays bit-identical to
/// today. Fiat is an offer, never a gate — the product is already live
/// Bitcoin-only before this is called, so dismissing or choosing Bitcoin sends
/// nothing.
Future<void> offerFiatSettlementAfterActivation(
  BuildContext context,
  FiatSettlementProduct product,
) async {
  if (!locator.isRegistered<GetSettingsUsecase>() ||
      !locator.isRegistered<FiatSettlementFacade>()) {
    return;
  }
  final settings = await locator<GetSettingsUsecase>().execute();
  // Mainnet-only surface: fiat settlement is not offered on testnet.
  if (settings.environment != Environment.mainnet) return;
  if (!context.mounted) return;
  await context.pushNamed(
    FiatSettlementRoute.fiatSettlementEditor.name,
    pathParameters: {'product': product.pathId},
    queryParameters: {'activated': '1'},
  );
}
