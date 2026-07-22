export 'package:bb_mobile/features/consolidation/ui/consolidation_router.dart';
export 'package:bb_mobile/features/consolidation/ui/widgets/consolidation_banner.dart';

/// Public contract of the `consolidation` feature. Other features must never
/// import `consolidation`'s `domain/`, `data/`, or `ui/` internals directly —
/// this facade (plus its `export`ed types/widgets) is the only surface.
///
/// This feature's actual "is consolidation required" check
/// ([CheckLiquidConsolidationUsecase]) lives in `core/wallet/domain/`, not
/// inside this feature, so it's already legitimately importable by any
/// feature directly (as shared core infrastructure) — it doesn't need to be
/// re-exported here. What this facade narrows is the feature-owned surface:
/// the route and the banner widgets consumers navigate to / render.
class ConsolidationFacade {
  const ConsolidationFacade();
}
