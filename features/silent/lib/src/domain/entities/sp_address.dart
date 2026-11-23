import 'package:silent/src/domain/entities/sp_address_kind.dart';

/// A recipient address the SP send flow accepts. User input is validated by BWK
/// before construction; this wrapper only keeps typed code from passing raw
/// strings further through the feature.
final class SilentAddress {
  final String value;
  final SilentAddressKind kind;

  /// Classifies [input] with no wrong-network guard, for an address bwk gave
  /// back rather than one the user typed. Throws on an unrecognized address:
  /// bwk echoing something we never sent is a bug.
  factory SilentAddress(String input) {
    final trimmed = input.trim();
    final kind = _classify(trimmed);
    if (kind == SilentAddressKind.unrecognized) {
      throw ArgumentError.value(input, 'input', 'unrecognized address');
    }
    return SilentAddress._(trimmed, kind);
  }

  const SilentAddress._(this.value, this.kind);

  /// Classify by address prefix. The longer prefixes (`sprt1`, `tsp1`, `bcrt1`)
  /// are matched before the shorter `sp1` and `bc1` so the network is picked
  /// unambiguously. Only bech32 separates testnet from regtest; the legacy
  /// base58 prefixes are shared, so they get their own kind.
  static SilentAddressKind _classify(String input) {
    final lower = input.toLowerCase();
    if (lower.startsWith('sprt1')) {
      return SilentAddressKind.silentPaymentRegtest;
    }
    if (lower.startsWith('tsp1')) return SilentAddressKind.silentPaymentTestnet;
    if (lower.startsWith('sp1')) return SilentAddressKind.silentPaymentMainnet;
    if (lower.startsWith('bcrt1')) return SilentAddressKind.bitcoinRegtest;
    if (lower.startsWith('bc1') ||
        lower.startsWith('1') ||
        lower.startsWith('3')) {
      return SilentAddressKind.bitcoinMainnet;
    }
    if (lower.startsWith('tb1')) return SilentAddressKind.bitcoinTestnet;
    if (lower.startsWith('m') ||
        lower.startsWith('n') ||
        lower.startsWith('2')) {
      return SilentAddressKind.bitcoinLegacyNonMainnet;
    }
    return SilentAddressKind.unrecognized;
  }

  bool get isSilentPayment => kind.isSilentPayment;
}
