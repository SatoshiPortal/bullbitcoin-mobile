import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/secrets_error.dart';

/// A public extended key (xpub/ypub/zpub/…). NON-secret.
@immutable
class Xpub {
  factory Xpub({required String value, required XpubType type}) {
    if (value.isEmpty) {
      throw InvalidXpubError('Xpub must not be empty', 'value');
    }
    return Xpub._(value, type);
  }
  const Xpub._(this.value, this.type);

  final String value;
  final XpubType type;

  @override
  bool operator ==(Object other) =>
      other is Xpub && other.value == value && other.type == type;

  @override
  int get hashCode => Object.hash(value, type);

  @override
  String toString() => 'Xpub($type, $value)';
}

/// Public (watch-only) Bitcoin descriptors. NON-secret.
@immutable
class BitcoinDescriptor {
  factory BitcoinDescriptor({
    required String external,
    required String internal,
  }) {
    if (external.isEmpty || internal.isEmpty) {
      throw InvalidDescriptorError('BitcoinDescriptor parts must not be empty');
    }
    return BitcoinDescriptor._(external, internal);
  }
  const BitcoinDescriptor._(this.external, this.internal);

  final String external;
  final String internal;

  @override
  bool operator ==(Object other) =>
      other is BitcoinDescriptor &&
      other.external == external &&
      other.internal == internal;

  @override
  int get hashCode => Object.hash(external, internal);

  @override
  String toString() => 'BitcoinDescriptor($external, $internal)';
}

/// A confidential Liquid descriptor string (`ct(slip77(KEY),elwpkh(XPUB))`).
/// WATCH-ONLY (no spending key) but PRIVACY-SENSITIVE: the
/// `slip77(...)` argument is the wallet's raw master blinding key, which lets
/// anyone holding it unblind every Liquid tx of this wallet forever. The value
/// is intentionally accessible (the app needs it to build a watch-only wallet),
/// but [toString] is REDACTED so it can never reach logs/Sentry.
@immutable
class LiquidDescriptor {
  factory LiquidDescriptor(String ctDescriptor) {
    if (ctDescriptor.isEmpty) {
      throw InvalidDescriptorError('must not be empty', 'ctDescriptor');
    }
    return LiquidDescriptor._(ctDescriptor);
  }
  const LiquidDescriptor._(this.ctDescriptor);

  final String ctDescriptor;

  @override
  bool operator ==(Object other) =>
      other is LiquidDescriptor && other.ctDescriptor == ctDescriptor;

  @override
  int get hashCode => ctDescriptor.hashCode;

  // Redacted: the ct descriptor embeds the master blinding key — never log it.
  @override
  String toString() =>
      'LiquidDescriptor(<redacted ct descriptor, ${ctDescriptor.length} chars>)';
}
