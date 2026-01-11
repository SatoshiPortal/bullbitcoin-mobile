import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

class SeedViewModel {
  final String fingerprint;
  final SeedSecret seedSecret;
  final bool isLegacy;
  final bool isInUse;
  // TODO: Replace the isInUse field with the actual usage data when available.
  //  A get usages use case should be created and called in the bloc to fetch this data.

  SeedViewModel({
    required this.fingerprint,
    required this.seedSecret,
    required this.isLegacy,
    required this.isInUse,
  });
}
