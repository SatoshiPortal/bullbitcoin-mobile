import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/coins/domain/utxo_sort_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wallet_utxo_fixture.dart';

void main() {
  group('sortAndFilterUtxos — sorting', () {
    test('amountDesc orders largest first', () {
      final utxos = [
        walletUtxoFixture(sats: 100, vout: 0),
        walletUtxoFixture(sats: 300, vout: 1),
        walletUtxoFixture(sats: 200, vout: 2),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(sort: CoinsSort.amountDesc),
      );
      expect(result.map((u) => u.amountSat.toInt()), [300, 200, 100]);
    });

    test('amountAsc orders smallest first', () {
      final utxos = [
        walletUtxoFixture(sats: 300, vout: 0),
        walletUtxoFixture(sats: 100, vout: 1),
        walletUtxoFixture(sats: 200, vout: 2),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(sort: CoinsSort.amountAsc),
      );
      expect(result.map((u) => u.amountSat.toInt()), [100, 200, 300]);
    });

    test('dateNewest orders fewest confirmations first (pending newest)', () {
      final utxos = [
        walletUtxoFixture(confirmations: 10, sats: 1, vout: 0),
        walletUtxoFixture(confirmations: 0, sats: 2, vout: 1),
        walletUtxoFixture(confirmations: 3, sats: 3, vout: 2),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(sort: CoinsSort.dateNewest),
      );
      expect(result.map((u) => u.confirmations), [0, 3, 10]);
    });

    test('dateOldest orders most confirmations first', () {
      final utxos = [
        walletUtxoFixture(confirmations: 0, sats: 1, vout: 0),
        walletUtxoFixture(confirmations: 10, sats: 2, vout: 1),
        walletUtxoFixture(confirmations: 3, sats: 3, vout: 2),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(sort: CoinsSort.dateOldest),
      );
      expect(result.map((u) => u.confirmations), [10, 3, 0]);
    });
  });

  group('sortAndFilterUtxos — frozen sinks to bottom', () {
    test('frozen coins are last regardless of sort', () {
      final utxos = [
        walletUtxoFixture(sats: 100, isFrozen: true, vout: 0),
        walletUtxoFixture(sats: 500, isFrozen: false, vout: 1),
        walletUtxoFixture(sats: 900, isFrozen: true, vout: 2),
        walletUtxoFixture(sats: 50, isFrozen: false, vout: 3),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(sort: CoinsSort.amountDesc),
      );
      // Unfrozen first (sorted), then frozen (sorted) at the bottom.
      expect(result.map((u) => u.isFrozen), [false, false, true, true]);
      expect(result.map((u) => u.amountSat.toInt()), [500, 50, 900, 100]);
    });
  });

  group('sortAndFilterUtxos — filters', () {
    test('keychain receive keeps only external', () {
      final utxos = [
        walletUtxoFixture(keychain: WalletAddressKeyChain.external, vout: 0),
        walletUtxoFixture(keychain: WalletAddressKeyChain.internal, vout: 1),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(keychain: KeychainFilter.receive),
      );
      expect(result, hasLength(1));
      expect(result.single.addressKeyChain, WalletAddressKeyChain.external);
    });

    test('keychain change keeps only internal', () {
      final utxos = [
        walletUtxoFixture(keychain: WalletAddressKeyChain.external, vout: 0),
        walletUtxoFixture(keychain: WalletAddressKeyChain.internal, vout: 1),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(keychain: KeychainFilter.change),
      );
      expect(result, hasLength(1));
      expect(result.single.addressKeyChain, WalletAddressKeyChain.internal);
    });

    test('frozen filter keeps only frozen', () {
      final utxos = [
        walletUtxoFixture(isFrozen: true, vout: 0),
        walletUtxoFixture(isFrozen: false, vout: 1),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(frozen: FrozenFilter.frozen),
      );
      expect(result, hasLength(1));
      expect(result.single.isFrozen, isTrue);
    });

    test('unfrozen filter keeps only unfrozen', () {
      final utxos = [
        walletUtxoFixture(isFrozen: true, vout: 0),
        walletUtxoFixture(isFrozen: false, vout: 1),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(frozen: FrozenFilter.unfrozen),
      );
      expect(result, hasLength(1));
      expect(result.single.isFrozen, isFalse);
    });

    test('label filter keeps coins matching any selected label', () {
      final utxos = [
        walletUtxoFixture(labels: ['savings'], vout: 0),
        walletUtxoFixture(labels: ['kyc'], vout: 1),
        walletUtxoFixture(labels: [], vout: 2),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(labels: {'savings'}),
      );
      expect(result, hasLength(1));
      expect(result.single.labels.single.label, 'savings');
    });
  });

  group('sortAndFilterUtxos — stable secondary key', () {
    test('equal confirmations break ties by amount then outpoint', () {
      final utxos = [
        walletUtxoFixture(confirmations: 5, sats: 100, txId: 'bbb', vout: 0),
        walletUtxoFixture(confirmations: 5, sats: 100, txId: 'aaa', vout: 0),
        walletUtxoFixture(confirmations: 5, sats: 200, txId: 'ccc', vout: 0),
      ];
      final result = sortAndFilterUtxos(
        utxos,
        const CoinsFilter(sort: CoinsSort.dateNewest),
      );
      // amount 200 first (tie-break amount desc), then equal-amount by txId.
      expect(result.map((u) => u.txId), ['ccc', 'aaa', 'bbb']);
    });

    test('is deterministic across repeated calls', () {
      final utxos = [
        for (var i = 0; i < 20; i++)
          walletUtxoFixture(
            confirmations: 1,
            sats: 1000,
            txId: 'tx$i',
            vout: 0,
          ),
      ];
      final first = sortAndFilterUtxos(utxos, const CoinsFilter());
      final second = sortAndFilterUtxos(
        utxos.reversed.toList(),
        const CoinsFilter(),
      );
      expect(first.map((u) => u.txId), second.map((u) => u.txId));
    });

    test('does not mutate the input list', () {
      final utxos = [
        walletUtxoFixture(sats: 100, vout: 0),
        walletUtxoFixture(sats: 300, vout: 1),
      ];
      final before = List.of(utxos);
      sortAndFilterUtxos(utxos, const CoinsFilter(sort: CoinsSort.amountDesc));
      expect(utxos, before);
    });
  });

  group('CoinsFilter value object', () {
    test('hasActiveFilter ignores sort', () {
      expect(
        const CoinsFilter(sort: CoinsSort.amountAsc).hasActiveFilter,
        isFalse,
      );
      expect(
        const CoinsFilter(frozen: FrozenFilter.frozen).hasActiveFilter,
        isTrue,
      );
    });

    test('activeFilterCount counts facets', () {
      const filter = CoinsFilter(
        keychain: KeychainFilter.change,
        frozen: FrozenFilter.frozen,
        labels: {'x'},
      );
      expect(filter.activeFilterCount, 3);
    });

    test('equality is by value', () {
      expect(
        const CoinsFilter(labels: {'a', 'b'}),
        const CoinsFilter(labels: {'b', 'a'}),
      );
    });
  });
}
