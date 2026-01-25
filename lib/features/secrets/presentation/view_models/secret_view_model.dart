import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';

class SecretViewModel {
  final Fingerprint fingerprint;
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
