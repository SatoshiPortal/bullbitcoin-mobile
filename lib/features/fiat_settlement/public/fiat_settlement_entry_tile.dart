import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_routes.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/fiat_settlement_copy.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:go_router/go_router.dart';

/// A self-contained "Fiat conversion" row a product screen can drop in. It is
/// MAINNET-ONLY (renders nothing on testnet), loads the product's current
/// settlement summary, and opens the shared editor, refreshing on return.
///
/// It depends only on the service locator (never the widget-tree cubits), so it
/// stays inert in isolated product-screen widget tests where those services are
/// not registered.
class FiatSettlementEntryTile extends StatefulWidget {
  const FiatSettlementEntryTile({super.key, required this.product});

  final FiatSettlementProduct product;

  @override
  State<FiatSettlementEntryTile> createState() =>
      _FiatSettlementEntryTileState();
}

class _FiatSettlementEntryTileState extends State<FiatSettlementEntryTile> {
  FiatSettlementProductConfig? _config;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!locator.isRegistered<GetSettingsUsecase>() ||
        !locator.isRegistered<FiatSettlementFacade>()) {
      return;
    }
    final settings = await locator<GetSettingsUsecase>().execute();
    // Mainnet-only surface: fiat settlement is not offered on testnet.
    if (settings.environment != Environment.mainnet) return;
    await _load();
    if (mounted) setState(() => _visible = true);
  }

  Future<void> _load() async {
    final result = await locator<FiatSettlementFacade>().configuration();
    if (!mounted) return;
    _config = switch (result) {
      Ok(:final value) => value.configFor(widget.product),
      Err() => FiatSettlementProductConfig(
        product: widget.product,
        fiatPercentage: 0,
        currency: null,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _config == null) return const SizedBox.shrink();

    final colors = context.bull;
    final config = _config!;
    return BullBorderedTile(
      onTap: () async {
        await context.pushNamed(
          FiatSettlementRoute.fiatSettlementEditor.name,
          pathParameters: {'product': widget.product.pathId},
        );
        await _load();
        if (mounted) setState(() {});
      },
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          BullIcon(Icons.currency_exchange, size: 24, color: colors.primary),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.getPaidFiatSettlementSectionTitle,
                  style: context.bullText.bodyMedium,
                ),
                const Gap(2),
                Text(
                  context.fiatSettlementSummary(config),
                  style: context.bullText.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          BullIcon(
            Icons.chevron_right,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
