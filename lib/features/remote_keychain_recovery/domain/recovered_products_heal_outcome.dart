import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';

/// Independent liveness outcomes for products restored from a manifest.
///
/// Later product features extend this contract with their own public outcome.
/// A null field means that product was not flagged for healing.
final class RecoveredProductsHealOutcome {
  final LightningAddressHealOutcome? lightningAddress;

  const RecoveredProductsHealOutcome({this.lightningAddress});
}
