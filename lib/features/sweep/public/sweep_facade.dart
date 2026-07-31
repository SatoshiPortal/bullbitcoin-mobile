export 'package:bb_mobile/features/sweep/ui/sweep_router.dart';

/// Public contract of the `sweep` feature. Other features must never import
/// `sweep`'s `domain/`, `presentation/` or `ui/` internals directly — this
/// facade and its `export`ed types are the only surface.
///
/// The feature is entered by navigation, so the contract is the route name plus
/// the [SweepArgs] a caller hands over. Everything else — the plan, the failure
/// family, the built PSBT — stays inside.
class SweepFacade {
  const SweepFacade();
}
