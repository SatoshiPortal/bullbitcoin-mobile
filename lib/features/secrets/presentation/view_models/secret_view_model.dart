import 'package:bb_mobile/core/primitives/secrets/secret.dart';

class SecretViewModel {
  final String fingerprint;
  final Secret secret;
  final bool isLegacy;
  final bool isInUse;
  // TODO: Replace the isInUse field with the actual usage data when available.
  //  A get usages use case should be created and called in the bloc to fetch this data.

  SecretViewModel({
    required this.fingerprint,
    required this.secret,
    required this.isLegacy,
    required this.isInUse,
  });
}
