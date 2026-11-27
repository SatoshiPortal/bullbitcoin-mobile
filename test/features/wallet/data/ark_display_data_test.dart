import 'dart:typed_data';

import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  final stamp = WalletRevision(
    key: WalletKey(id: 'selected-source', network: BitcoinNetwork.regtest),
    generation: 3,
    revision: 7,
  );
  const point = (txId: 'public-source-transaction', vout: 0);
  Balances values(int spendable) => Balances(
    confirmedSat: BigInt.from(2000),
    immatureSat: BigInt.zero,
    trustedPendingSat: BigInt.zero,
    untrustedPendingSat: BigInt.zero,
    spendableSat: BigInt.from(spendable),
    totalSat: BigInt.from(2000),
  );
  CoinList coins({bool frozen = false}) => CoinList([
    BitcoinCoin(
      outpoint: point,
      amountSat: BigInt.from(2000),
      scriptPubkey: Uint8List(0),
      address: null,
      keychain: Keychain.external,
      confirmations: 2,
      frozen: frozen,
    ),
  ]);
  Sats? read({
    int amount = 1234,
    WalletBalances? balance,
    WalletRevisionState? revision,
    bool frozen = false,
    Set<Outpoint> held = const {},
  }) => availableArkSourceBalance(
    stamp: stamp,
    balance: balance ?? WalletValue.ready(values(amount), stamp),
    revision:
        revision ??
        WalletRevisionState(stamp: stamp, lifecycle: WalletLifecycle.active),
    coins: coins(frozen: frozen),
    reservations: held,
  );

  test('uses the trusted source balance rather than summing all outputs', () {
    expect(read(), Sats.fromInt(1234));
    expect(read(amount: 0), Sats.zero);
  });
  test('stale, unavailable and negative values remain unknown', () {
    expect(read(balance: WalletValue.stale(values(1234), stamp)), isNull);
    expect(read(balance: const WalletValue.notLoaded()), isNull);
    expect(read(balance: const WalletValue.closed()), isNull);
    expect(read(amount: -1), isNull);
  });
  test('another revision, ended generation or failed sync remains unknown', () {
    final other = WalletRevision(key: stamp.key, generation: 4, revision: 7);
    expect(read(balance: WalletValue.ready(values(1234), other)), isNull);
    expect(
      read(
        revision: WalletRevisionState(
          stamp: other,
          lifecycle: WalletLifecycle.active,
        ),
      ),
      isNull,
    );
    expect(
      read(
        revision: WalletRevisionState(
          stamp: stamp,
          lifecycle: WalletLifecycle.deleted,
        ),
      ),
      isNull,
    );
    expect(
      read(
        revision: WalletRevisionState(
          stamp: stamp,
          lifecycle: WalletLifecycle.active,
          syncFailed: true,
        ),
      ),
      isNull,
    );
  });
  test('a frozen or Board-held output comes off the available amount', () {
    // The only coin is protected: nothing is left for a new Board.
    expect(read(amount: 2000, frozen: true), Sats.zero);
    expect(read(amount: 2000, held: {point}), Sats.zero);
    // The rest of the wallet stays available.
    expect(read(amount: 5000, held: {point}), Sats.fromInt(3000));
    expect(read(amount: 5000, frozen: true, held: {point}), Sats.fromInt(3000));
    expect(read(held: {(txId: 'unrelated', vout: 1)}), Sats.fromInt(1234));
  });
}
