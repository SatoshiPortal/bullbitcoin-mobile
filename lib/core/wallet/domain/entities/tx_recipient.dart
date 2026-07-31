/// One output of a transaction under construction.
///
/// Two shapes, because an output either pins an exact amount or absorbs what
/// is left of the inputs:
///
/// - [FixedTxRecipient] — an explicit amount in satoshis.
/// - [DrainTxRecipient] — takes every remaining satoshi of the inputs after
///   the fixed recipients and the network fee, so the transaction carries no
///   change output at all.
///
/// A build carries **at most one** [DrainTxRecipient]. With none, whatever is
/// left over returns to the spending wallet's own change output — the default
/// for a coin sweep, where the point is to control the *inputs*, not to hand
/// the residue to a third party.
///
/// Self-validating: an instance that would produce an invalid output cannot
/// exist. Kept free of any SDK type so it can cross the repository boundary.
sealed class TxRecipient {
  /// The destination address, as typed/scanned. Network validity is the
  /// caller's concern — the SDK rejects a foreign-network address at build.
  final String address;

  const TxRecipient._(this.address);

  /// The pinned amount, or `null` when this recipient drains the remainder.
  BigInt? get amountSat;
}

/// An output with an explicit amount.
final class FixedTxRecipient extends TxRecipient {
  @override
  final BigInt amountSat;

  FixedTxRecipient({required String address, required this.amountSat})
    : super._(address) {
    if (address.trim().isEmpty) {
      throw ArgumentError.value(address, 'address', 'must not be empty');
    }
    if (amountSat <= BigInt.zero) {
      throw ArgumentError.value(amountSat, 'amountSat', 'must be positive');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FixedTxRecipient &&
      other.address == address &&
      other.amountSat == amountSat;

  @override
  int get hashCode => Object.hash(address, amountSat);

  @override
  String toString() => 'FixedTxRecipient($address, $amountSat sats)';
}

/// The output that absorbs the remainder of the inputs, net of fees.
///
/// Maps to BDK's `drain_to`: it replaces the change output rather than adding
/// one, which is what makes a full sweep leave nothing behind.
final class DrainTxRecipient extends TxRecipient {
  DrainTxRecipient({required String address}) : super._(address) {
    if (address.trim().isEmpty) {
      throw ArgumentError.value(address, 'address', 'must not be empty');
    }
  }

  @override
  BigInt? get amountSat => null;

  @override
  bool operator ==(Object other) =>
      other is DrainTxRecipient && other.address == address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'DrainTxRecipient($address)';
}
