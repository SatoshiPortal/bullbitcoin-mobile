import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('security-sensitive operational logging', () {
    test('does not interpolate Bitcoin wallet or UTXO details', () {
      final source = File(
        'lib/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart',
      ).readAsStringSync();

      expect(source, contains('Bitcoin PSBT preparation:'));
      for (final sensitiveInterpolation in [
        r'$walletId',
        r'$unspendableUtxos',
        r'$address',
        r'${address}',
        r'$txId',
        r'${txId}',
        r'$psbt',
        r'${psbt}',
      ]) {
        expect(source, isNot(contains(sensitiveInterpolation)));
      }
      expect(source, isNot(contains('Unspendable utxos:')));
    });

    test('does not interpolate swap amounts or order identifiers', () {
      final source = File(
        'lib/features/swap/data/order_swap_repository_impl.dart',
      ).readAsStringSync();

      expect(source, contains(r'fixedInput=$isInAmountFixed'));
      for (final sensitiveInterpolation in [
        r'amountSat=$amountSat',
        r'requestId=${record.requestId}',
        r'requestId=${created.requestId}',
        r'orderNumber=${order.orderNumber}',
        r'orderId=${_shortOrderId(order.orderId)}',
        r'$destinationAddress',
        r'${destinationAddress}',
        r'$sourceWalletId',
        r'$destinationWalletId',
        r'$transactionId',
        r'$signedTransaction',
        r'$signedPayinTransaction',
        r'$error',
        r'${error}',
        r'${error.toString()}',
      ]) {
        expect(source, isNot(contains(sensitiveInterpolation)));
      }
      expect(source, isNot(contains('_shortOrderId')));
    });

    test('does not interpolate transfer fee amounts or transaction sizes', () {
      final source = File(
        'lib/features/swap/presentation/transfer_bloc.dart',
      ).readAsStringSync();

      expect(source, isNot(contains(r'$absoluteFees')));
      expect(source, isNot(contains(r'$bitcoinAbsoluteFeesSat')));
      expect(source, isNot(contains(r'${signedPsbtAndTxSize.txSize}')));
      expect(source, contains('Bitcoin fee estimate calculated'));
      expect(source, contains('Liquid fee estimate calculated'));
    });
  });
}
