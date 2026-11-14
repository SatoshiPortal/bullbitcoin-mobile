import 'dart:typed_data';

import 'package:primitives/primitives.dart';

import 'wallet_key.dart';
import 'wallet_revision.dart';

/// A protocol session that may spend the inputs it reserved, and only those.
/// Sync checks the claim against the reservations its owner publishes; a
/// session that holds no reservation of the wallet gains nothing.
///
/// ⚠️ A user freeze is never exempted, whoever spends.
final class SpendOwner {
  /// The reserving protocol, such as `payjoin`.
  final String protocol;
  final String session;

  SpendOwner({required this.protocol, required this.session}) {
    if (protocol.isEmpty || session.isEmpty) {
      throw ArgumentError('A spend owner needs its protocol and session');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SpendOwner &&
      other.protocol == protocol &&
      other.session == session;

  @override
  int get hashCode => Object.hash(protocol, session);
}

/// What a spend pays in fees.
sealed class SpendFee {
  const SpendFee();
}

/// A rate in sat per 1000 weight units: BDK's exact unit, four times LWK's
/// sat/kvB.
final class SpendFeeRate extends SpendFee {
  final int satPerKwu;

  SpendFeeRate(this.satPerKwu) {
    if (satPerKwu <= 0) throw ArgumentError.value(satPerKwu, 'satPerKwu');
  }
}

/// An absolute fee, Bitcoin only.
final class SpendAbsoluteFee extends SpendFee {
  final int sats;

  SpendAbsoluteFee(this.sats) {
    if (sats < 0) throw ArgumentError.value(sats, 'sats');
  }
}

/// One payee. A null [amountSat] receives what remains once the others and
/// the fee are paid.
final class SpendRecipient {
  final String address;
  final int? amountSat;

  SpendRecipient(this.address, {this.amountSat}) {
    if (address.isEmpty) throw ArgumentError('A recipient needs an address');
    if (amountSat case final amount? when amount <= 0) {
      throw ArgumentError.value(amount, 'amountSat');
    }
  }
}

/// A transaction to build. [exclude] only ever narrows the coins sync may
/// use: freezes and other sessions' reservations are always excluded.
sealed class SpendRequest {
  final Set<Outpoint> exclude;

  /// The session spending its own reservations, if any.
  final SpendOwner? owner;

  SpendRequest({Set<Outpoint> exclude = const {}, this.owner})
    : exclude = Set.unmodifiable(exclude);
}

final class BitcoinSpendRequest extends SpendRequest {
  final List<SpendRecipient> recipients;
  final SpendFee fee;

  /// Coins that must be spent. With [selectedOnly], no other coin is.
  final List<Outpoint>? selected;
  final bool selectedOnly;

  /// Signals BIP125 replaceability, BDK's default.
  final bool replaceable;

  BitcoinSpendRequest({
    required List<SpendRecipient> recipients,
    required this.fee,
    List<Outpoint>? selected,
    this.selectedOnly = false,
    this.replaceable = true,
    super.exclude,
    super.owner,
  }) : recipients = List.unmodifiable(recipients),
       selected = selected == null ? null : List.unmodifiable(selected) {
    if (recipients.isEmpty) throw ArgumentError('A spend needs a recipient');
    if (recipients.where((recipient) => recipient.amountSat == null).length >
        1) {
      throw ArgumentError('At most one recipient receives the remainder');
    }
  }
}

/// A Liquid L-BTC payment to one address. A null [amountSat] drains every
/// spendable coin to it.
final class LiquidSpendRequest extends SpendRequest {
  final String address;
  final int? amountSat;
  final SpendFeeRate fee;

  /// Coins that must be spent, and no other.
  final Set<Outpoint>? selected;

  LiquidSpendRequest({
    required this.address,
    required this.fee,
    this.amountSat,
    Set<Outpoint>? selected,
    super.exclude,
  }) : selected = selected == null ? null : Set.unmodifiable(selected) {
    if (address.isEmpty) throw ArgumentError('A spend needs an address');
    if (amountSat case final amount? when amount <= 0) {
      throw ArgumentError.value(amount, 'amountSat');
    }
  }
}

/// A BIP125 replacement of this wallet's [txid] at a higher [fee] rate.
final class BumpFeeRequest {
  final String txid;
  final SpendFeeRate fee;

  /// The session whose reservations the original spent, if any: the
  /// replacement may reuse those original inputs, never another's.
  final SpendOwner? owner;

  BumpFeeRequest({required this.txid, required this.fee, this.owner}) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid)) {
      throw ArgumentError.value(txid, 'txid');
    }
  }
}

/// Liquid consolidation: confirmed L-BTC coins swept into self-payments of at
/// most [maximumInputs] inputs each, once the wallet holds more than
/// [highUtxoThreshold] of them.
final class ConsolidationRequest {
  final SpendFeeRate fee;
  final int highUtxoThreshold;
  final int maximumInputs;

  ConsolidationRequest({
    required this.fee,
    required this.highUtxoThreshold,
    required this.maximumInputs,
  }) {
    if (highUtxoThreshold < 0 || maximumInputs <= 0) {
      throw ArgumentError('Invalid consolidation bounds');
    }
  }
}

/// A transaction the writer built and checked, before any signature.
///
/// [revision] is the wallet's committed revision once the build's native
/// changes were persisted; its generation is checked again at broadcast.
final class UnsignedSpend {
  final WalletRevision revision;

  /// Base64 PSBT for Bitcoin, base64 PSET for Liquid.
  final String encoded;

  /// The effective inputs, as built.
  final List<Outpoint> inputs;
  final SpendOwner? owner;

  /// The transaction this one replaces, for a fee bump.
  final String? replacing;

  UnsignedSpend({
    required this.revision,
    required this.encoded,
    required List<Outpoint> inputs,
    this.owner,
    this.replacing,
  }) : inputs = List.unmodifiable(inputs);

  WalletKey get key => revision.key;

  /// This spend once signed, ready for `wallet.spend.broadcast`.
  SignedSpend signed(SignedTransaction transaction) => SignedSpend._(
    key: key,
    generation: revision.generation,
    builtAt: revision,
    transaction: transaction,
    owner: owner,
    replacing: replacing,
  );
}

/// A signed transaction, in the form its signer returned.
sealed class SignedTransaction {
  const SignedTransaction();
}

/// A finalized Bitcoin PSBT, base64.
final class SignedPsbt extends SignedTransaction {
  final String psbt;
  const SignedPsbt(this.psbt);
}

/// A Bitcoin transaction's consensus bytes.
final class SignedBitcoinTransaction extends SignedTransaction {
  final Uint8List bytes;
  SignedBitcoinTransaction(List<int> bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
}

/// A signed Liquid PSET, base64.
final class SignedPset extends SignedTransaction {
  final String pset;
  const SignedPset(this.pset);
}

/// A signed transaction to broadcast for a wallet generation. Built from an
/// [UnsignedSpend], or by `wallet.spend.signed` for a transaction signed in
/// an earlier run, such as a Payjoin proposal or a saved payment.
final class SignedSpend {
  final WalletKey key;
  final int generation;

  /// The revision it was built at, when this run built it.
  final WalletRevision? builtAt;
  final SignedTransaction transaction;
  final SpendOwner? owner;
  final String? replacing;

  SignedSpend._({
    required this.key,
    required this.generation,
    required this.builtAt,
    required this.transaction,
    required this.owner,
    required this.replacing,
  });
}

/// Internal: lets the public wallet handle mint a [SignedSpend] for its own
/// generation. Not exported.
SignedSpend signedForGeneration({
  required WalletKey key,
  required int generation,
  required SignedTransaction transaction,
  SpendOwner? owner,
  String? replacing,
}) => SignedSpend._(
  key: key,
  generation: generation,
  builtAt: null,
  transaction: transaction,
  owner: owner,
  replacing: replacing,
);

/// The network accepted [txid].
///
/// [durable] says whether the Bitcoin guard recorded it: until it does, the
/// wallet keeps refusing spends in this process. [guarded] is false for
/// Liquid, which has no spend guard yet: nothing protects a concurrent spend
/// of its inputs, and nothing is recorded.
final class SpendReceipt {
  final String txid;
  final bool durable;
  final bool guarded;

  const SpendReceipt(this.txid, {required this.durable, required this.guarded});
}

/// Whether the wallet's own inputs of a stored transaction carry valid
/// signatures (GHSA-6jp4-8v48-cc5v): a replacement is only built on [valid].
enum SignatureCheck { valid, invalid, unverifiable }

/// What a Liquid PSET does to this wallet's L-BTC: [policyBalanceSat] is the
/// net change (negative for a payment), fee included.
final class LiquidPsetEffect {
  final int policyBalanceSat;
  final int feeSat;

  const LiquidPsetEffect({
    required this.policyBalanceSat,
    required this.feeSat,
  });
}
