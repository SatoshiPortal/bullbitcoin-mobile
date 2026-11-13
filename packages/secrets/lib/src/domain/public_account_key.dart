import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Public account information derived together from one secret.
final class PublicAccountKey {
  final Fingerprint fingerprint;
  final String xpub;
  final String derivationPath;

  @internal
  const PublicAccountKey({
    required this.fingerprint,
    required this.xpub,
    required this.derivationPath,
  });
}

/// One selected public key occurrence in a descriptor.
final class DescriptorSigningKey {
  final String publicExpression;
  final String derivationPath;
  final String xpub;

  DescriptorSigningKey({
    required this.publicExpression,
    required this.derivationPath,
    required this.xpub,
  }) {
    if (publicExpression.isEmpty || derivationPath.isEmpty || xpub.isEmpty) {
      throw ArgumentError('A descriptor signing key must be complete');
    }
  }
}
