import 'dart:typed_data';

import 'package:primitives/primitives.dart';

import 'sync_failure.dart';
import 'wallet_revision.dart';

/// Where a published value stands. Only [ready] and [stale] carry data; an
/// unavailable wallet never reads as a zero balance or an empty list.
enum ValueStatus {
  /// Nothing published yet for this wallet in this isolate.
  notLoaded,

  /// Mapped from the revision in [WalletValue.revision].
  ready,

  /// The last coherent data, kept while the wallet is busy or its sync failed.
  stale,

  /// No data: [WalletValue.failure] says why.
  unavailable,

  /// The owning [Sync] was closed.
  closed,
}

/// One published wallet value with its availability and stamp.
final class WalletValue<D extends Object> {
  final ValueStatus status;
  final WalletRevision? revision;
  final SyncFailure? failure;
  final D? data;

  const WalletValue._(this.status, this.revision, this.failure, this.data);

  const WalletValue.notLoaded()
    : this._(ValueStatus.notLoaded, null, null, null);
  const WalletValue.closed() : this._(ValueStatus.closed, null, null, null);
  const WalletValue.unavailable(SyncFailure failure, [WalletRevision? revision])
    : this._(ValueStatus.unavailable, revision, failure, null);
  const WalletValue.ready(D data, WalletRevision revision)
    : this._(ValueStatus.ready, revision, null, data);

  /// [failure] is the reason the data could not be refreshed, if known.
  const WalletValue.stale(
    D data,
    WalletRevision revision, [
    SyncFailure? failure,
  ]) : this._(ValueStatus.stale, revision, failure, data);

  /// The published data, which may be stale, or the read failure.
  Result<D, SyncFailure> get latest => switch (data) {
    final value? => Ok(value),
    null => Err(failure ?? const SyncBusyFailure()),
  };

  /// Same projection: status, generation, failure category and data. A newer
  /// revision with identical data is not a change.
  bool samePublication(WalletValue<D> other) =>
      status == other.status &&
      revision?.generation == other.revision?.generation &&
      failure?.runtimeType == other.failure?.runtimeType &&
      data == other.data;
}

typedef WalletBalances = WalletValue<Balances>;
typedef WalletCoins = WalletValue<CoinList>;
typedef WalletTransactions = WalletValue<ChainTransactionList>;
typedef WalletAddresses = WalletValue<AddressBook>;
typedef WalletAddressAt = WalletValue<DerivedAddress>;
typedef WalletOwnership = WalletValue<Ownership>;

/// Satoshi amounts. Liquid reports its L-BTC balance as confirmed, spendable
/// and total; its pending categories are zero.
final class Balances {
  final BigInt confirmedSat;
  final BigInt immatureSat;
  final BigInt trustedPendingSat;
  final BigInt untrustedPendingSat;
  final BigInt spendableSat;
  final BigInt totalSat;

  const Balances({
    required this.confirmedSat,
    required this.immatureSat,
    required this.trustedPendingSat,
    required this.untrustedPendingSat,
    required this.spendableSat,
    required this.totalSat,
  });

  @override
  bool operator ==(Object other) =>
      other is Balances &&
      other.confirmedSat == confirmedSat &&
      other.immatureSat == immatureSat &&
      other.trustedPendingSat == trustedPendingSat &&
      other.untrustedPendingSat == untrustedPendingSat &&
      other.spendableSat == spendableSat &&
      other.totalSat == totalSat;

  @override
  int get hashCode => Object.hash(
    confirmedSat,
    immatureSat,
    trustedPendingSat,
    untrustedPendingSat,
    spendableSat,
    totalSat,
  );
}

enum Keychain { external, internal }

/// An unspent output. Liquid lists L-BTC coins only.
sealed class Coin {
  final Outpoint outpoint;
  final BigInt amountSat;

  /// A user froze this outpoint: no spend may use it. Applied from the
  /// freeze store at publication, never mapped from the native wallet.
  final bool frozen;

  const Coin(this.outpoint, this.amountSat, {this.frozen = false});

  /// This coin with [frozen] set, sharing every other field.
  Coin withFrozen(bool frozen);
}

final class BitcoinCoin extends Coin {
  final Uint8List scriptPubkey;

  /// Null for a script without an address form.
  final String? address;
  final Keychain keychain;

  /// From the wallet's own tip; zero while unconfirmed.
  final int confirmations;

  BitcoinCoin({
    required Outpoint outpoint,
    required BigInt amountSat,
    required Uint8List scriptPubkey,
    required this.address,
    required this.keychain,
    required this.confirmations,
    super.frozen,
  }) : scriptPubkey = Uint8List.fromList(scriptPubkey).asUnmodifiableView(),
       super(outpoint, amountSat);

  BitcoinCoin._shared(BitcoinCoin coin, {required super.frozen})
    : scriptPubkey = coin.scriptPubkey,
      address = coin.address,
      keychain = coin.keychain,
      confirmations = coin.confirmations,
      super(coin.outpoint, coin.amountSat);

  @override
  BitcoinCoin withFrozen(bool frozen) =>
      frozen == this.frozen ? this : BitcoinCoin._shared(this, frozen: frozen);

  @override
  bool operator ==(Object other) =>
      other is BitcoinCoin &&
      other.outpoint == outpoint &&
      other.amountSat == amountSat &&
      other.frozen == frozen &&
      _bytesEqual(other.scriptPubkey, scriptPubkey) &&
      other.address == address &&
      other.keychain == keychain &&
      other.confirmations == confirmations;

  @override
  int get hashCode =>
      Object.hash(outpoint, amountSat, address, confirmations, frozen);
}

final class LiquidCoin extends Coin {
  /// Hex, as LWK reports it.
  final String scriptPubkey;
  final String standardAddress;
  final String confidentialAddress;
  final int? blockHeight;

  const LiquidCoin({
    required Outpoint outpoint,
    required BigInt amountSat,
    required this.scriptPubkey,
    required this.standardAddress,
    required this.confidentialAddress,
    required this.blockHeight,
    super.frozen,
  }) : super(outpoint, amountSat);

  @override
  LiquidCoin withFrozen(bool frozen) => frozen == this.frozen
      ? this
      : LiquidCoin(
          outpoint: outpoint,
          amountSat: amountSat,
          scriptPubkey: scriptPubkey,
          standardAddress: standardAddress,
          confidentialAddress: confidentialAddress,
          blockHeight: blockHeight,
          frozen: frozen,
        );

  @override
  bool operator ==(Object other) =>
      other is LiquidCoin &&
      other.outpoint == outpoint &&
      other.amountSat == amountSat &&
      other.frozen == frozen &&
      other.scriptPubkey == scriptPubkey &&
      other.standardAddress == standardAddress &&
      other.confidentialAddress == confidentialAddress &&
      other.blockHeight == blockHeight;

  @override
  int get hashCode => Object.hash(outpoint, amountSat, blockHeight, frozen);
}

/// Unmodifiable list with element-wise equality.
final class CoinList extends _ValueList<Coin> {
  CoinList(super.items);

  /// These coins with the freezes in [frozen] applied; this list itself
  /// when nothing changes.
  CoinList withFrozen(Set<Outpoint> frozen) {
    final coins = [
      for (final coin in this) coin.withFrozen(frozen.contains(coin.outpoint)),
    ];
    var changed = false;
    for (var i = 0; i < coins.length; i++) {
      changed = changed || !identical(coins[i], this[i]);
    }
    return changed ? CoinList(coins) : this;
  }
}

final class ChainTransactionList extends _ValueList<ChainTransaction> {
  ChainTransactionList(super.items);
}

/// A wallet transaction as the chain and the wallet's index describe it.
/// Presentation choices (direction, net amount) belong to the consumer.
sealed class ChainTransaction {
  final String txid;

  /// Null when the wallet does not know every previous output (Bitcoin).
  final int? feeSat;
  final int vsize;

  /// Unix seconds of the confirming block; null while unconfirmed.
  final int? confirmationTime;

  const ChainTransaction({
    required this.txid,
    required this.feeSat,
    required this.vsize,
    required this.confirmationTime,
  });
}

final class BitcoinTransaction extends ChainTransaction {
  final List<BitcoinInput> inputs;
  final List<BitcoinOutput> outputs;
  final int sentSat;
  final int receivedSat;
  final bool isExplicitlyRbf;

  BitcoinTransaction({
    required super.txid,
    required super.feeSat,
    required super.vsize,
    required super.confirmationTime,
    required List<BitcoinInput> inputs,
    required List<BitcoinOutput> outputs,
    required this.sentSat,
    required this.receivedSat,
    required this.isExplicitlyRbf,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);

  @override
  bool operator ==(Object other) =>
      other is BitcoinTransaction &&
      other.txid == txid &&
      other.feeSat == feeSat &&
      other.vsize == vsize &&
      other.confirmationTime == confirmationTime &&
      other.sentSat == sentSat &&
      other.receivedSat == receivedSat &&
      other.isExplicitlyRbf == isExplicitlyRbf &&
      _listEqual(other.inputs, inputs) &&
      _listEqual(other.outputs, outputs);

  @override
  int get hashCode => Object.hash(txid, confirmationTime, sentSat, receivedSat);
}

final class BitcoinInput {
  final Outpoint previousOutput;
  final Uint8List scriptSig;

  BitcoinInput({required this.previousOutput, required Uint8List scriptSig})
    : scriptSig = Uint8List.fromList(scriptSig).asUnmodifiableView();

  @override
  bool operator ==(Object other) =>
      other is BitcoinInput &&
      other.previousOutput == previousOutput &&
      _bytesEqual(other.scriptSig, scriptSig);

  @override
  int get hashCode => previousOutput.hashCode;
}

final class BitcoinOutput {
  final int vout;
  final BigInt valueSat;
  final Uint8List scriptPubkey;
  final String? address;

  /// The wallet's index knows this script, revealed or within the lookahead.
  final bool isOwn;

  /// Owned by the internal keychain.
  final bool isChange;

  BitcoinOutput({
    required this.vout,
    required this.valueSat,
    required Uint8List scriptPubkey,
    required this.address,
    required this.isOwn,
    required this.isChange,
  }) : scriptPubkey = Uint8List.fromList(scriptPubkey).asUnmodifiableView();

  @override
  bool operator ==(Object other) =>
      other is BitcoinOutput &&
      other.vout == vout &&
      other.valueSat == valueSat &&
      _bytesEqual(other.scriptPubkey, scriptPubkey) &&
      other.address == address &&
      other.isOwn == isOwn &&
      other.isChange == isChange;

  @override
  int get hashCode => Object.hash(vout, valueSat, address, isOwn, isChange);
}

/// LWK lists only the inputs and outputs that belong to this wallet.
final class LiquidTransaction extends ChainTransaction {
  /// LWK's classification: incoming, outgoing, redeposit, ...
  final String kind;

  /// Signed L-BTC balance change; zero when LWK reports none.
  final int policyBalanceSat;
  final String unblindedUrl;
  final List<LiquidTxOut> inputs;
  final List<LiquidTxOut> outputs;

  LiquidTransaction({
    required super.txid,
    required super.feeSat,
    required super.vsize,
    required super.confirmationTime,
    required this.kind,
    required this.policyBalanceSat,
    required this.unblindedUrl,
    required List<LiquidTxOut> inputs,
    required List<LiquidTxOut> outputs,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);

  @override
  bool operator ==(Object other) =>
      other is LiquidTransaction &&
      other.txid == txid &&
      other.feeSat == feeSat &&
      other.vsize == vsize &&
      other.confirmationTime == confirmationTime &&
      other.kind == kind &&
      other.policyBalanceSat == policyBalanceSat &&
      other.unblindedUrl == unblindedUrl &&
      _listEqual(other.inputs, inputs) &&
      _listEqual(other.outputs, outputs);

  @override
  int get hashCode => Object.hash(txid, confirmationTime, policyBalanceSat);
}

final class LiquidTxOut {
  final Outpoint outpoint;
  final BigInt valueSat;

  /// Hex, as LWK reports it.
  final String scriptPubkey;
  final String standardAddress;
  final String confidentialAddress;
  final bool isPolicyAsset;

  const LiquidTxOut({
    required this.outpoint,
    required this.valueSat,
    required this.scriptPubkey,
    required this.standardAddress,
    required this.confidentialAddress,
    required this.isPolicyAsset,
  });

  @override
  bool operator ==(Object other) =>
      other is LiquidTxOut &&
      other.outpoint == outpoint &&
      other.valueSat == valueSat &&
      other.scriptPubkey == scriptPubkey &&
      other.standardAddress == standardAddress &&
      other.confidentialAddress == confidentialAddress &&
      other.isPolicyAsset == isPolicyAsset;

  @override
  int get hashCode => Object.hash(outpoint, valueSat, isPolicyAsset);
}

/// Current unspent balance and number of transactions paying an address.
typedef AddressUsage = ({BigInt balanceSat, int transactionCount});

/// An address derived from the descriptor, without revealing anything.
/// Bitcoin fills [address]; Liquid fills both forms, [address] confidential.
final class DerivedAddress {
  final Keychain keychain;
  final int index;
  final String address;
  final String? standardAddress;

  const DerivedAddress({
    required this.keychain,
    required this.index,
    required this.address,
    this.standardAddress,
  });

  @override
  bool operator ==(Object other) =>
      other is DerivedAddress &&
      other.keychain == keychain &&
      other.index == index &&
      other.address == address &&
      other.standardAddress == standardAddress;

  @override
  int get hashCode => Object.hash(keychain, index, address);
}

/// The addresses the wallet's index has reached. Bitcoin: last revealed
/// index per keychain, -1 when none. Liquid: the last unused external index
/// and no change keychain, which LWK does not expose.
final class AddressBook {
  final int receiveIndex;
  final int? changeIndex;

  /// Indexes 0..[receiveIndex], then 0..[changeIndex].
  final List<DerivedAddress> receive;
  final List<DerivedAddress> change;

  AddressBook({
    required this.receiveIndex,
    required this.changeIndex,
    required List<DerivedAddress> receive,
    required List<DerivedAddress> change,
  }) : receive = List.unmodifiable(receive),
       change = List.unmodifiable(change);

  DerivedAddress? at(int index, Keychain keychain) {
    final list = keychain == Keychain.external ? receive : change;
    return index >= 0 && index < list.length ? list[index] : null;
  }

  @override
  bool operator ==(Object other) =>
      other is AddressBook &&
      other.receiveIndex == receiveIndex &&
      other.changeIndex == changeIndex &&
      _listEqual(other.receive, receive) &&
      _listEqual(other.change, change);

  @override
  int get hashCode => Object.hash(receiveIndex, changeIndex, receive.length);
}

/// Answer of an ownership query, from the wallet's index (revealed scripts
/// plus the lookahead; outputs already spent included).
final class Ownership {
  final bool owned;

  const Ownership(this.owned);

  @override
  bool operator ==(Object other) => other is Ownership && other.owned == owned;

  @override
  int get hashCode => owned.hashCode;
}

abstract base class _ValueList<T> extends Iterable<T> {
  final List<T> _items;

  _ValueList(List<T> items) : _items = List.unmodifiable(items);

  @override
  Iterator<T> get iterator => _items.iterator;

  @override
  int get length => _items.length;

  T operator [](int index) => _items[index];

  @override
  bool operator ==(Object other) =>
      other is _ValueList<T> &&
      other.runtimeType == runtimeType &&
      _listEqual(other._items, _items);

  @override
  int get hashCode => Object.hashAll(_items);
}

bool _listEqual<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Exact ownership at one committed revision: scripts the wallet's index
/// derives (revealed plus lookahead) and every output it holds or held,
/// spent ones included. Immutable; a later revision needs a new query.
final class OwnershipIndex {
  final WalletRevision revision;
  final Set<String> _scripts;
  final Set<Outpoint> _outpoints;

  OwnershipIndex({
    required this.revision,
    required Iterable<Uint8List> scripts,
    required Iterable<Outpoint> outpoints,
  }) : _scripts = Set.unmodifiable(scripts.map(_hex)),
       _outpoints = Set.unmodifiable(outpoints);

  bool ownsScript(Uint8List script) => _scripts.contains(_hex(script));

  bool ownsOutpoint(Outpoint outpoint) => _outpoints.contains(outpoint);

  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
