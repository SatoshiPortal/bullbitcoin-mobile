import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/bull_ark.dart'
    show
        ArkFailure,
        ArkFeatureStorageFailure,
        ArkServiceUnavailableFailure,
        ArkAccountRecoveryFailure;
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;

/// Observations only: no coin selection, address allocation or funding writes.
final class WalletArkDisplayData implements ArkDisplayDataPort {
  final WalletNativeRuntime _runtime;
  final ArkAccountId _account;
  final Future<Result<String, ArkFailure>> Function(ArkAccountId)
  _selectedSource;
  final Future<String> Function() _currency;
  final Future<ArkSourceWalletName?> Function(String walletId) _walletName;
  final IndexPriceReader _price;
  final bool Function() _isActive;
  final _pending = <Future<Result<ArkDisplayData, ArkFailure>>>{};
  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<String> _currencySubscription;
  late final StreamSubscription<WalletRevisionState> _sourceSubscription;
  String? _walletId;
  bool _closed = false;

  WalletArkDisplayData({
    required this._runtime,
    required this._account,
    required Stream<String> currencyChanges,
    required this._selectedSource,
    required this._currency,
    required this._walletName,
    required this._isActive,
    this._price = _readIndexPrice,
  }) {
    _currencySubscription = currencyChanges.listen((_) {
      if (_live) _changes.add(null);
    });
    _sourceSubscription = _runtime.changes.listen((revision) {
      if (_live &&
          revision.stamp.key.id == _walletId &&
          revision.stamp.key.network == _account.network) {
        _changes.add(null);
      }
    });
  }

  @override
  Stream<void> changes(ArkAccountId account) =>
      account == _account ? _changes.stream : const Stream.empty();

  @override
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account) {
    if (account != _account) {
      return Future.value(const Err(ArkAccountRecoveryFailure()));
    }
    if (!_live) return Future.value(const Err(ArkServiceUnavailableFailure()));
    final pending = _read(account);
    _pending.add(pending);
    return pending.whenComplete(() => _pending.remove(pending));
  }

  bool get _live => !_closed && _isActive();

  Future<void> close() async {
    _closed = true;
    await Future.wait([
      _currencySubscription.cancel(),
      _sourceSubscription.cancel(),
    ]);
    await Future.wait(_pending);
    await _changes.close();
  }

  Future<Result<ArkDisplayData, ArkFailure>> _read(ArkAccountId account) async {
    try {
      final selected = await _selectedSource(account);
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      if (selected case Err(:final failure)) return Err(failure);
      final id = (selected as Ok<String, ArkFailure>).value;
      _walletId = id;
      final result = await _runtime.wallet(
        WalletKey(id: id, network: account.network),
      );
      if (result case Err()) return const Err(ArkFeatureStorageFailure());
      final handle = (result as Ok<Wallet, SyncFailure>).value;
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      if (handle.key.network != account.network) {
        return const Err(ArkFeatureStorageFailure());
      }
      final loaded = await handle.load();
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      if (loaded case Err()) return const Err(ArkFeatureStorageFailure());
      final stamp = (loaded as Ok<WalletRevision, SyncFailure>).value;
      final coins = await handle.unspent();
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      final reservations = await _runtime.readReservedOutpointsForDisplay();
      if (reservations case Err()) return const Err(ArkFeatureStorageFailure());
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      final code = await _currency();
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      final currency = SupportedCurrency.tryFromCode(code);
      BitcoinPrice? price;
      if (currency != null) {
        final result = await _price(
          network: account.network,
          currency: currency,
        );
        if (result case Ok(:final value) when value.currency == currency) {
          if (await _currency() == code) price = value;
        }
      }
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      final current = await _runtime.readRevision(handle.key);
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      final stillSelected = await _selectedSource(account);
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      if (stillSelected case Err(:final failure)) return Err(failure);
      if ((stillSelected as Ok<String, ArkFailure>).value != id) {
        return const Err(ArkFeatureStorageFailure());
      }
      if (price != null && await _currency() != code) price = null;
      // A missing name only falls back to a generic label in the review.
      final name = await _walletName(id);
      if (!_live) return const Err(ArkServiceUnavailableFailure());
      Sats? available;
      if (coins case Ok(:final value)) {
        if (reservations case Ok(value: final held?)) {
          if (current case Ok(value: final revision)) {
            available = availableArkSourceBalance(
              stamp: stamp,
              balance: handle.balances.now,
              revision: revision,
              coins: value,
              reservations: held,
            );
          }
        }
      }
      return Ok(
        ArkDisplayData(
          account: account,
          walletId: id,
          available: available,
          price: price,
          walletName: name,
        ),
      );
    } on Exception {
      return const Err(ArkFeatureStorageFailure());
    }
  }
}

Future<Result<BitcoinPrice, PricerFailure>> _readIndexPrice({
  required BitcoinNetwork network,
  required SupportedCurrency currency,
}) => Pricer.getIndexPrice(network: network, currency: currency);

/// An incoherent observation is unknown, never a guessed maximum. Protected
/// coins are left out of the amount rather than hiding it.
@visibleForTesting
Sats? availableArkSourceBalance({
  required WalletRevision stamp,
  required WalletBalances balance,
  required WalletRevisionState revision,
  required CoinList coins,
  required Set<Outpoint> reservations,
}) {
  final value = balance.data;
  if (balance.status != ValueStatus.ready ||
      value == null ||
      balance.revision != stamp ||
      revision.stamp != stamp ||
      revision.lifecycle != WalletLifecycle.active ||
      revision.syncFailed ||
      value.spendableSat < BigInt.zero) {
    return null;
  }
  // A coin a pending Board holds, or the user froze, cannot fund this Board,
  // but the rest of the wallet still can: the native balance knows neither,
  // so they come off it. A held coin outside the trusted balance only makes
  // the amount shown smaller, never larger.
  var protected = BigInt.zero;
  for (final coin in coins) {
    if (coin.frozen || reservations.contains(coin.outpoint)) {
      protected += coin.amountSat;
    }
  }
  final free = value.spendableSat - protected;
  return Sats(free < BigInt.zero ? BigInt.zero : free);
}
