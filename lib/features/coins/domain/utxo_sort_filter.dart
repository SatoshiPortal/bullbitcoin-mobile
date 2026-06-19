import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

/// How the visible UTXO list is ordered (frozen always sink to the bottom
/// regardless of the chosen sort — see [sortAndFilterUtxos]).
enum CoinsSort {
  /// Largest amount first.
  amountDesc,

  /// Smallest amount first.
  amountAsc,

  /// Newest first — fewest confirmations first (pending `0` is newest).
  dateNewest,

  /// Oldest first — most confirmations first.
  dateOldest,
}

/// Keychain filter — which derivation branch a coin belongs to.
enum KeychainFilter { all, receive, change }

/// Frozen-status filter.
enum FrozenFilter { all, frozen, unfrozen }

/// Immutable filter/sort criteria applied to the UTXO list. A value object —
/// equality is by value so the cubit can compare and detect "no active filter".
class CoinsFilter {
  const CoinsFilter({
    this.sort = CoinsSort.amountDesc,
    this.keychain = KeychainFilter.all,
    this.frozen = FrozenFilter.all,
    this.labels = const {},
  });

  final CoinsSort sort;
  final KeychainFilter keychain;
  final FrozenFilter frozen;
  final Set<String> labels;

  /// Whether any *filter* (not sort) is narrowing the list. Drives the
  /// "filter active" red dot and the filtered-empty state.
  bool get hasActiveFilter =>
      keychain != KeychainFilter.all ||
      frozen != FrozenFilter.all ||
      labels.isNotEmpty;

  /// Number of active filter facets — drives the count badge.
  int get activeFilterCount {
    var count = 0;
    if (keychain != KeychainFilter.all) count++;
    if (frozen != FrozenFilter.all) count++;
    if (labels.isNotEmpty) count++;
    return count;
  }

  CoinsFilter copyWith({
    CoinsSort? sort,
    KeychainFilter? keychain,
    FrozenFilter? frozen,
    Set<String>? labels,
  }) {
    return CoinsFilter(
      sort: sort ?? this.sort,
      keychain: keychain ?? this.keychain,
      frozen: frozen ?? this.frozen,
      labels: labels ?? this.labels,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoinsFilter &&
        other.sort == sort &&
        other.keychain == keychain &&
        other.frozen == frozen &&
        _setEquals(other.labels, labels);
  }

  @override
  int get hashCode =>
      Object.hash(sort, keychain, frozen, Object.hashAllUnordered(labels));
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  for (final e in a) {
    if (!b.contains(e)) return false;
  }
  return true;
}

/// Returns the outpoint key `txId:vout` for a UTXO — the stable identity used
/// for selection and as the final secondary sort key.
String utxoOutpointKey(WalletUtxo utxo) => '${utxo.txId}:${utxo.vout}';

/// Pure transform: filter then sort a list of [WalletUtxo].
///
/// Rules:
/// - Frozen coins always sink to the bottom, regardless of [CoinsFilter.sort].
/// - Within each group (unfrozen, then frozen) the chosen sort applies.
/// - Sorting is **stable & deterministic**: equal primary keys break ties by
///   amount (descending) then by `txId:vout` so the order never flickers.
/// - Does not mutate the input list.
List<WalletUtxo> sortAndFilterUtxos(
  List<WalletUtxo> utxos,
  CoinsFilter filter,
) {
  final filtered = utxos.where((u) => _matchesFilter(u, filter)).toList();

  filtered.sort((a, b) {
    // Frozen always sinks below unfrozen.
    if (a.isFrozen != b.isFrozen) {
      return a.isFrozen ? 1 : -1;
    }

    final primary = _primaryCompare(a, b, filter.sort);
    if (primary != 0) return primary;

    return _stableSecondary(a, b);
  });

  return filtered;
}

bool _matchesFilter(WalletUtxo utxo, CoinsFilter filter) {
  switch (filter.keychain) {
    case KeychainFilter.receive:
      if (utxo.addressKeyChain != WalletAddressKeyChain.external) return false;
    case KeychainFilter.change:
      if (utxo.addressKeyChain != WalletAddressKeyChain.internal) return false;
    case KeychainFilter.all:
      break;
  }

  switch (filter.frozen) {
    case FrozenFilter.frozen:
      if (!utxo.isFrozen) return false;
    case FrozenFilter.unfrozen:
      if (utxo.isFrozen) return false;
    case FrozenFilter.all:
      break;
  }

  if (filter.labels.isNotEmpty) {
    // Match the same label union the tile displays (output + address + tx
    // labels), so filtering by any label visible on a coin actually selects it.
    final utxoLabels = <String>{
      ...utxo.labels.map((l) => l.label),
      ...utxo.addressLabels.map((l) => l.label),
      ...utxo.txLabels.map((l) => l.label),
    };
    final intersects = filter.labels.any(utxoLabels.contains);
    if (!intersects) return false;
  }

  return true;
}

int _primaryCompare(WalletUtxo a, WalletUtxo b, CoinsSort sort) {
  switch (sort) {
    case CoinsSort.amountDesc:
      return b.amountSat.compareTo(a.amountSat);
    case CoinsSort.amountAsc:
      return a.amountSat.compareTo(b.amountSat);
    case CoinsSort.dateNewest:
      // Fewer confirmations = newer; pending (0) is newest.
      return a.confirmations.compareTo(b.confirmations);
    case CoinsSort.dateOldest:
      return b.confirmations.compareTo(a.confirmations);
  }
}

/// Deterministic tie-break: amount descending, then outpoint key.
int _stableSecondary(WalletUtxo a, WalletUtxo b) {
  final byAmount = b.amountSat.compareTo(a.amountSat);
  if (byAmount != 0) return byAmount;
  return utxoOutpointKey(a).compareTo(utxoOutpointKey(b));
}
