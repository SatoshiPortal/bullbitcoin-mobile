import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/tx_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';

/// One row of the allocation form, already parsed out of its text fields.
///
/// [amountSat] is `null` while the row is empty; [takesRemainder] is the "Max"
/// toggle, which makes this row absorb whatever the other rows and the network
/// fee leave behind. The two are distinct on purpose: an untyped amount is a
/// mistake to report, not an implicit "send everything here".
final class SweepAllocation {
  final String address;
  final BigInt? amountSat;
  final bool takesRemainder;

  const SweepAllocation({
    required this.address,
    this.amountSat,
    this.takesRemainder = false,
  });

  SweepAllocation copyWith({
    String? address,
    BigInt? amountSat,
    bool clearAmount = false,
    bool? takesRemainder,
  }) {
    return SweepAllocation(
      address: address ?? this.address,
      amountSat: clearAmount ? null : (amountSat ?? this.amountSat),
      takesRemainder: takesRemainder ?? this.takesRemainder,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SweepAllocation &&
      other.address == address &&
      other.amountSat == amountSat &&
      other.takesRemainder == takesRemainder;

  @override
  int get hashCode => Object.hash(address, amountSat, takesRemainder);
}

/// A validated coin sweep: the exact coins to spend, and how their value is
/// split across outputs.
///
/// Cannot be constructed in an invalid state — [validate] is the only way in,
/// and it returns the broken rule as a [SweepFailure] rather than throwing, so
/// the form can report it inline.
///
/// A plan carries **at most one** remainder recipient. With none, whatever is
/// left after the fixed recipients and the fee returns to the spending wallet's
/// own change output; that's the default, since the point of a sweep is to
/// control which coins are spent, not to give the residue away.
final class SweepPlan {
  final List<WalletUtxo> inputs;
  final List<TxRecipient> recipients;

  const SweepPlan._({required this.inputs, required this.recipients});

  /// The dust threshold for an output paying [address], in satoshis.
  ///
  /// Bitcoin Core's threshold is per script type, not a single number, because
  /// it prices the cost of spending the output again. Using one blanket floor
  /// would reject perfectly relayable payments: 546 is the *P2PKH* figure, and
  /// applying it to a bech32 recipient refuses anything under 546 when the
  /// network happily relays 294.
  ///
  /// Derived from the address prefix rather than from a parsed script, so this
  /// stays pure Dart. An unrecognised prefix falls back to the highest
  /// threshold — the SDK is the final authority either way and rejects a dust
  /// output at build time, so erring high here only ever costs a clearer
  /// message, never a lost payment.
  static BigInt minimumOutputSatFor(String address) {
    final a = address.trim().toLowerCase();

    // Taproot (P2TR) and P2WSH: 32-byte witness programs.
    if (a.startsWith('bc1p') ||
        a.startsWith('tb1p') ||
        a.startsWith('bcrt1p')) {
      return BigInt.from(330);
    }
    if (a.startsWith('bc1q') ||
        a.startsWith('tb1q') ||
        a.startsWith('bcrt1q')) {
      // A 20-byte program (P2WPKH) encodes to 42 chars on mainnet/testnet;
      // anything longer is a 32-byte P2WSH program.
      return a.length <= 44 ? BigInt.from(294) : BigInt.from(330);
    }
    // P2SH (mainnet '3', testnet '2').
    if (a.startsWith('3') || a.startsWith('2')) return BigInt.from(540);
    // P2PKH (mainnet '1', testnet 'm'/'n') and anything unrecognised.
    return BigInt.from(546);
  }

  /// The lowest threshold any supported script type can have — the floor a
  /// caller can quote before an address is known.
  static final minimumOutputSat = BigInt.from(294);

  /// Validates [allocations] against [inputs].
  ///
  /// Rules are checked in the order a user would fix them, so the first
  /// reported failure is the most useful one.
  static Result<SweepPlan, SweepFailure> validate({
    required List<WalletUtxo> inputs,
    required List<SweepAllocation> allocations,
  }) {
    if (inputs.isEmpty) return const Err(SweepNoInputsFailure());
    if (allocations.isEmpty) return const Err(SweepNoRecipientsFailure());

    if (allocations.any((a) => a.address.trim().isEmpty)) {
      return const Err(SweepMissingAddressFailure());
    }

    final addresses = allocations.map((a) => a.address.trim()).toList();
    final seen = <String>{};
    for (final address in addresses) {
      if (!seen.add(address)) {
        return Err(SweepDuplicateAddressFailure(address));
      }
    }

    final remainderRows = allocations.where((a) => a.takesRemainder).length;
    if (remainderRows > 1) {
      return const Err(SweepMultipleRemainderFailure());
    }

    final fixedRows = allocations.where((a) => !a.takesRemainder);
    if (fixedRows.any((a) => a.amountSat == null)) {
      return const Err(SweepMissingAmountFailure());
    }
    // Per-recipient, because the threshold depends on the destination's script
    // type — one blanket number would refuse relayable payments.
    for (final row in fixedRows) {
      final minimum = minimumOutputSatFor(row.address);
      if (row.amountSat! < minimum) {
        return Err(SweepAmountBelowDustFailure(minimum));
      }
    }

    final totalInputSat = _sumInputs(inputs);
    final allocatedSat = fixedRows.fold(
      BigInt.zero,
      (sum, a) => sum + a.amountSat!,
    );

    if (allocatedSat > totalInputSat) {
      return Err(
        SweepAllocationExceedsBalanceFailure(allocatedSat - totalInputSat),
      );
    }
    // Equality is still invalid: the miner has to be paid out of the same
    // coins, and a remainder row would end up with nothing.
    if (allocatedSat == totalInputSat) {
      return const Err(SweepNoRoomForFeeFailure());
    }

    final recipients = allocations
        .map<TxRecipient>(
          (a) => a.takesRemainder
              ? DrainTxRecipient(address: a.address.trim())
              : FixedTxRecipient(
                  address: a.address.trim(),
                  amountSat: a.amountSat!,
                ),
        )
        .toList();

    return Ok(
      SweepPlan._(
        inputs: List.unmodifiable(inputs),
        recipients: List.unmodifiable(recipients),
      ),
    );
  }

  /// Total value of the coins being spent.
  BigInt get totalInputSat => _sumInputs(inputs);

  /// Sum of the pinned recipient amounts.
  BigInt get allocatedSat => recipients.whereType<FixedTxRecipient>().fold(
    BigInt.zero,
    (sum, r) => sum + r.amountSat,
  );

  /// What the fixed recipients leave on the table, before the network fee.
  /// Either drains to a remainder recipient or returns as change.
  BigInt get unallocatedSat => totalInputSat - allocatedSat;

  /// Whether a recipient absorbs the remainder, which suppresses the change
  /// output entirely.
  bool get hasRemainderRecipient =>
      recipients.any((r) => r is DrainTxRecipient);

  /// The change that returns to the spending wallet once the real [feeSat] is
  /// known, or `null` when a remainder recipient takes it instead.
  ///
  /// A result at or below [minimumOutputSat] means the network would treat the
  /// change as dust; the SDK then folds it into the fee rather than creating
  /// the output.
  BigInt? changeSat(BigInt feeSat) =>
      hasRemainderRecipient ? null : unallocatedSat - feeSat;

  /// What the remainder recipient actually receives once [feeSat] is known,
  /// or `null` when there is no remainder recipient.
  BigInt? remainderSat(BigInt feeSat) =>
      hasRemainderRecipient ? unallocatedSat - feeSat : null;

  List<Outpoint> get outpoints =>
      inputs.map((u) => (txId: u.txId, vout: u.vout)).toList();

  static BigInt _sumInputs(List<WalletUtxo> inputs) =>
      inputs.fold(BigInt.zero, (sum, u) => sum + u.amountSat);
}
