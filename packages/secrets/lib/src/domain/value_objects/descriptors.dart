import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// A public extended key (xpub/ypub/zpub/…). NON-secret.
@immutable
class Xpub {
  factory Xpub({required String value, required XpubType type}) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Xpub must not be empty');
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
      throw ArgumentError('BitcoinDescriptor parts must not be empty');
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

/// A confidential Liquid descriptor string. NON-secret (watch-only ct).
@immutable
class LiquidDescriptor {
  factory LiquidDescriptor(String ctDescriptor) {
    if (ctDescriptor.isEmpty) {
      throw ArgumentError.value(
          ctDescriptor, 'ctDescriptor', 'must not be empty');
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

  @override
  String toString() => 'LiquidDescriptor($ctDescriptor)';
}
