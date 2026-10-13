import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BdkBitcoinBlockchainDatasource.isUnknownTransactionReply', () {
    test('recognizes the electrs and esplora reply', () {
      expect(
        BdkBitcoinBlockchainDatasource.isUnknownTransactionReply(
          '{"code":-32603,"message":"missing transaction"}',
        ),
        isTrue,
      );
    });

    test('recognizes the Fulcrum reply relayed from bitcoind', () {
      expect(
        BdkBitcoinBlockchainDatasource.isUnknownTransactionReply(
          "daemon error: DaemonError({'code': -5, 'message': 'No such mempool "
          "or blockchain transaction. Use gettransaction for wallet "
          "transactions.'})",
        ),
        isTrue,
      );
    });

    test('treats any other server error as unknown, not absent', () {
      expect(
        BdkBitcoinBlockchainDatasource.isUnknownTransactionReply(
          'excessive resource usage',
        ),
        isFalse,
      );
    });
  });
}
