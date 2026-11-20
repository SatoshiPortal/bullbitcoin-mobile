import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_order_mapper.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';

import '../../../core/exchange/order_json_fixture.dart';

/// Every field the old parser reads, set.
const _allFields = <String, Object?>{
  'orderSubtype': 'Express',
  'indexRateAmount': 99000.5,
  'indexRateCurrency': 'CAD',
  'scheduledPayoutTime': '2026-07-01T13:00:00.000Z',
  'completedAt': '2026-07-01T14:00:00.000Z',
  'message': {'code': 3, 'message': 'Delayed'},
  'sentAt': '2026-07-01T13:30:00.000Z',
  'bitcoinTransactionId': 'btc-tx',
  'lnUrl': 'lnurl1',
  'lightningVoucherExpiresAt': '2026-07-02T12:00:00.000Z',
  'isPPBitcoinOutUpdatable': true,
  'payinAmountChanged': {'requestedAmount': 100, 'receivedAmount': 90.5},
  'lightningInvoice': 'lnbc1',
  'bitcoinAddress': 'bc1q',
  'liquidAddress': 'lq1',
  'liquidTransactionId': 'lq-tx',
  'lightningAddress': 'a@b.c',
  'beneficiaryName': 'Hydro',
  'beneficiaryLabel': 'Home',
  'beneficiaryAccountNumber': '123',
  'beneficiaryETransferAddress': 'pay@example.com',
  'securityQuestion': 'q',
  'securityAnswer': 'a',
  'paymentDescription': 'Invoice 9',
  'unbatchedBuyOnchainFees': 125,
  'bip21URI': 'bitcoin:bc1q?amount=0.001&pj=https://pj.example',
  'payjoinDetails': {'txid': 'pj-tx', 'ignored': 1},
  'referenceNumber': 'ref-1',
  'originName': 'Origin',
  'originCedula': '1-234',
};

/// An admin-initiated order: no pay-in side, no rate, no deadline.
const _sparse = <String, Object?>{
  'exchangeRateAmount': null,
  'exchangeRateCurrency': null,
  'payinAmount': null,
  'payinCurrency': null,
  'payoutAmount': null,
  'payoutCurrency': null,
  'orderStatus': null,
  'payinStatus': null,
  'payoutStatus': null,
  'payinMethod': null,
  'payoutMethod': null,
  'triggerType': null,
  'confirmationDeadline': null,
};

const _orderTypes = [
  'Buy Bitcoin',
  'Sell Bitcoin',
  'Sell USDT',
  'Fiat Payment',
  'Funding',
  'Withdraw',
  'Reward',
  'Refund',
  'Balance Adjustment',
  'Buy Gold Bars',
];

Order _old(Map<String, dynamic> json, {bool isTestnet = false}) =>
    OrderModel.fromJson(json).toEntity(isTestnet: isTestnet);

Order _new(Map<String, dynamic> json, {bool isTestnet = false}) =>
    orderFromBbxApi(bbx.OrderSummary.fromJson(json), isTestnet: isTestnet);

/// The entity's fields, including the nested objects that have no `==`.
String _snapshot(Order order) {
  final o = order as dynamic;
  Object? field(Object? Function() read) {
    try {
      return read();
    } on NoSuchMethodError {
      return 'n/a';
    }
  }

  final changed = field(() => o.payinAmountChanged);
  final payjoin = field(() => o.payjoinDetails);
  return [
    order.runtimeType,
    order,
    order.message.code,
    order.message.message,
    if (changed is PayinAmountChanged)
      '${changed.requestedAmount}/${changed.receivedAmount}'
    else
      changed,
    if (payjoin is OrderPayjoinDetails) 'txid ${payjoin.txid}' else payjoin,
  ].join('\n');
}

void main() {
  group('orderFromBbxApi gives the entity the old parser gave', () {
    for (final orderType in _orderTypes) {
      for (final (name, overrides) in [
        ('all fields', _allFields),
        ('sparse', _sparse),
        (
          'unparseable optional dates',
          const <String, Object?>{
            'confirmationDeadline': 'soon',
            'completedAt': 'x',
            'sentAt': '',
            'scheduledPayoutTime': 'later',
            'lightningVoucherExpiresAt': 'never',
          },
        ),
        (
          'partial nested objects',
          const <String, Object?>{
            'message': {'code': null},
            'payinAmountChanged': <String, Object?>{},
            'payjoinDetails': <String, Object?>{},
          },
        ),
      ]) {
        for (final isTestnet in [false, true]) {
          test('$orderType, $name, testnet: $isTestnet', () {
            final json = orderJsonFixture(
              orderType: orderType,
              overrides: overrides,
            );
            expect(
              _snapshot(_new(json, isTestnet: isTestnet)),
              _snapshot(_old(json, isTestnet: isTestnet)),
            );
          });
        }
      }
    }

    test('unknown statuses and methods fall back the same way', () {
      final json = orderJsonFixture(
        orderStatus: 'Some Future Status',
        payinStatus: '',
        payoutStatus: 'Another Future Status',
        overrides: const {'payinMethod': 'Gold', 'payoutMethod': ''},
      );
      expect(_snapshot(_new(json)), _snapshot(_old(json)));
      expect(_new(json).orderStatus, OrderStatus.unknown);
    });

    test('an invalid createdAt throws a FormatException in both', () {
      final json = orderJsonFixture(overrides: const {'createdAt': 'not'});
      expect(() => _old(json), throwsFormatException);
      expect(() => _new(json), throwsFormatException);
    });
  });

  group('orderSummaryMatchesTxId', () {
    final summary = bbx.OrderSummary.fromJson(
      orderJsonFixture(overrides: _allFields),
    );
    final model = OrderModel.fromJson(orderJsonFixture(overrides: _allFields));

    for (final txId in ['btc-tx', 'lq-tx', 'pj-tx', 'other']) {
      test(txId, () {
        expect(orderSummaryMatchesTxId(summary, txId), model.matchesTxId(txId));
      });
    }

    test('an order without payjoin details matches only its own txids', () {
      final plain = bbx.OrderSummary.fromJson(orderJsonFixture());
      expect(orderSummaryMatchesTxId(plain, 'pj-tx'), isFalse);
    });
  });
}
