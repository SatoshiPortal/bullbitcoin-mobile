import 'package:bb_mobile/features/address_view/data/address_overview_model.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:flutter_test/flutter_test.dart';

const _balance =
    '{"jsonrpc":"2.0","id":1,"result":{"confirmed":150000,"unconfirmed":-2500}}';
const _history =
    '{"jsonrpc":"2.0","id":2,"result":['
    '{"tx_hash":"aa","height":100},'
    '{"tx_hash":"bb","height":0,"fee":200},'
    '{"tx_hash":"cc","height":250},'
    '{"tx_hash":"dd","height":-1,"fee":300}]}';

void main() {
  group('AddressOverviewModel.fromResponseLines', () {
    test('parses balance and history', () {
      final model = AddressOverviewModel.fromResponseLines([
        _balance,
        _history,
      ]);

      expect(model.confirmedSat, 150000);
      expect(model.unconfirmedSat, -2500);
      expect(model.history.map((item) => item.txid), ['aa', 'bb', 'cc', 'dd']);
      expect(model.history.map((item) => item.height), [100, 0, 250, -1]);
    });

    test('matches responses by id, not by order', () {
      final model = AddressOverviewModel.fromResponseLines([
        _history,
        _balance,
      ]);

      expect(model.confirmedSat, 150000);
      expect(model.history, hasLength(4));
    });

    test('rejects an error response', () {
      expect(
        () => AddressOverviewModel.fromResponseLines([
          '{"jsonrpc":"2.0","id":1,"error":{"code":1,"message":"x"}}',
          _history,
        ]),
        throwsFormatException,
      );
    });

    test('rejects a missing response', () {
      expect(
        () => AddressOverviewModel.fromResponseLines([_balance]),
        throwsFormatException,
      );
    });

    test('rejects a malformed history item', () {
      expect(
        () => AddressOverviewModel.fromResponseLines([
          _balance,
          '{"jsonrpc":"2.0","id":2,"result":[{"tx_hash":1,"height":"x"}]}',
        ]),
        throwsFormatException,
      );
    });
  });

  test('toEntity puts unconfirmed first, then newest block first', () {
    final overview = AddressOverviewModel.fromResponseLines([
      _balance,
      _history,
    ]).toEntity(address: 'address', network: Network.bitcoinMainnet);

    expect(overview.address, 'address');
    expect(overview.network, Network.bitcoinMainnet);
    expect(overview.confirmedSat, 150000);
    expect(overview.unconfirmedSat, -2500);
    expect(overview.transactionCount, 4);
    expect(overview.transactions.map((tx) => tx.txid), [
      'bb',
      'dd',
      'cc',
      'aa',
    ]);
    expect(overview.transactions.map((tx) => tx.isConfirmed), [
      false,
      false,
      true,
      true,
    ]);
  });
}
