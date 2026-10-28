import 'dart:typed_data';

import 'package:bb_mobile/bbx_api_setup.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('orders', () {
    Map<String, dynamic> orderJson({
      String orderType = 'Buy Bitcoin',
      String? confirmationDeadline = '2026-07-28T12:05:00.000Z',
      Map<String, dynamic>? payjoinDetails,
      Map<String, dynamic>? payinAmountChanged,
    }) => {
      'orderId': 'order-1',
      'orderType': orderType,
      'orderNumber': 7,
      'exchangeRateAmount': 100000.5,
      'exchangeRateCurrency': 'CAD',
      'payinAmount': 100.0,
      'payinCurrency': 'CAD',
      'payoutAmount': 0.001,
      'payoutCurrency': 'BTC',
      'orderStatus': 'In progress',
      'payinStatus': 'Awaiting payment',
      'payoutStatus': 'Not started',
      'createdAt': '2026-07-28T12:00:00.000Z',
      'completedAt': '2026-07-28T13:00:00.000Z',
      'confirmationDeadline': ?confirmationDeadline,
      'message': <String, dynamic>{'code': 'C1', 'message': 'hello'},
      'payinMethod': 'CAD Balance',
      'payoutMethod': 'Bitcoin On-Chain',
      'triggerType': 'USER',
      'bitcoinAddress': 'bc1qexample',
      'bip21URI': 'bitcoin:bc1qexample?pj=https://example.com',
      'unbatchedBuyOnchainFees': 0.00001,
      'payjoinDetails': ?payjoinDetails,
      'payinAmountChanged': ?payinAmountChanged,
    };

    Order viaPackage(Map<String, dynamic> json) =>
        BbxApiMapper.orderFromSummary(
          bbx.OrderSummaryModel.fromJson(
            json,
            fallbacks: BbxApiSetup.orderSummaryParsing.fallbacks,
          ),
          isTestnet: true,
        );

    test('a buy order maps every field', () {
      final json = orderJson(
        payjoinDetails: {'txid': 'abc', 'paymentAmount': 1000},
        payinAmountChanged: {'requestedAmount': 1.0, 'receivedAmount': 2.0},
      );

      final order = viaPackage(json) as BuyOrder;

      expect(order.orderId, 'order-1');
      expect(order.orderNumber, 7);
      expect(order.orderType, OrderType.buy);
      expect(order.exchangeRateAmount, 100000.5);
      expect(order.payinAmount, 100.0);
      expect(order.payoutAmount, 0.001);
      expect(order.orderStatus, OrderStatus.inProgress);
      expect(order.payinStatus, OrderPayinStatus.awaitingPayment);
      expect(order.payoutStatus, OrderPayoutStatus.notStarted);
      expect(order.payinMethod, OrderPaymentMethod.cadBalance);
      expect(order.payoutMethod, OrderPaymentMethod.bitcoin);
      expect(order.message.code, 'C1');
      expect(order.message.message, 'hello');
      expect(order.createdAt, DateTime.utc(2026, 7, 28, 12));
      expect(order.completedAt, DateTime.utc(2026, 7, 28, 13));
      expect(order.confirmationDeadline, DateTime.utc(2026, 7, 28, 12, 5));
      expect(order.payjoinDetails?.txid, 'abc');
      expect(order.bip21URI, 'bitcoin:bc1qexample?pj=https://example.com');
      expect(order.unbatchedBuyOnchainFees, 0.00001);
      expect(order.payinAmountChanged?.requestedAmount, 1.0);
      expect(order.payinAmountChanged?.receivedAmount, 2.0);
      expect(order.isTestnet, isTrue);
    });

    test('a sell order maps to a sell order', () {
      expect(
        viaPackage(orderJson(orderType: 'Sell Bitcoin')),
        isA<SellOrder>(),
      );
    });

    test('a missing confirmation deadline stays absent', () {
      final json = orderJson(confirmationDeadline: null);

      expect(viaPackage(json).confirmationDeadline, isNull);
    });

    test('a missing payin or payout amount reads as zero', () {
      final json = orderJson()
        ..remove('payinAmount')
        ..remove('payoutAmount');

      final order = viaPackage(json);

      expect(order.payinAmount, 0);
      expect(order.payoutAmount, 0);
    });

    test('the ARS referral payout maps with the server spelling', () {
      final json = orderJson()..['payoutMethod'] = 'Referral Payout  ARS';

      expect(viaPackage(json).payoutMethod, OrderPaymentMethod.referralArs);
    });

    test('matches an order by any of its transaction ids', () {
      final summary = bbx.OrderSummaryModel.fromJson({
        ...orderJson(payjoinDetails: {'txid': 'p' * 64}),
        'bitcoinTransactionId': 'b' * 64,
      });

      expect(BbxApiMapper.orderMatchesTxId(summary, 'p' * 64), isTrue);
      expect(BbxApiMapper.orderMatchesTxId(summary, 'b' * 64), isTrue);
      expect(BbxApiMapper.orderMatchesTxId(summary, 'x' * 64), isFalse);
    });

    test('a recurring buy maps to the DCA entity', () {
      final summary = bbx.RecurringBuyOrderSummaryModel.fromJson({
        'amountStr': '25.5',
        'currencyCode': 'CAD',
        'recurringFrequency': 'WEEKLY',
        'recipientType': 'OUT_LIGHTNING_ADDRESS',
        'address': 'me@example.com',
        'createdAt': '2026-07-28T12:00:00.000Z',
        'nextRunAt': '2026-08-04T12:00:00.000Z',
      });

      final dca = BbxApiMapper.dcaFromRecurringBuy(summary);

      expect(dca.amount, 25.5);
      expect(dca.currency, FiatCurrency.cad);
      expect(dca.frequency, DcaBuyFrequency.weekly);
      expect(dca.network, DcaNetwork.lightning);
      expect(dca.address, 'me@example.com');
      expect(dca.nextPurchaseDate, DateTime.utc(2026, 8, 4, 12));
    });
  });

  test('the user summary maps every field', () {
    final json = _userSummaryJson();
    final mapped = BbxApiMapper.userSummary(
      bbx.UserSummaryModel.fromJson(json),
    );

    expect(
      mapped,
      const UserSummary(
        userNumber: 42,
        userId: 'user-1',
        groups: ['KYC_IDENTITY_VERIFIED', 'JURI_EU'],
        profile: UserProfile(firstName: 'Test', lastName: 'User'),
        email: 'test.user@example.com',
        balances: [
          UserBalance(amount: 10.5, currencyCode: 'CAD'),
          UserBalance(amount: 0, currencyCode: 'EUR'),
        ],
        language: 'EN',
        currency: 'CAD',
        dca: UserDca(
          isActive: true,
          frequency: DcaBuyFrequency.daily,
          amount: 20,
          currency: FiatCurrency.eur,
          network: DcaNetwork.bitcoin,
          address: 'bc1qexample',
        ),
        autoBuy: UserAutoBuy(
          isActive: true,
          addresses: UserAutoBuyAddresses(
            bitcoin: 'bc1qexample',
            liquid: 'lq1example',
          ),
        ),
        emailNotificationsEnabled: false,
        payjoinReceiveEnabled: true,
        kycDocumentStatus: UserKycDocumentStatus(
          secureFileUpload: KycDocumentStatus.underReview,
          documents: UserKycDocuments(
            id: KycDocumentStatus.accepted,
            proofOfResidence: KycDocumentStatus.rejected,
            selfie: KycDocumentStatus.notUploaded,
          ),
        ),
      ),
    );
  });

  group('support chat', () {
    test('attachments keep the app filter and message id fallback', () {
      final message = bbx.MessageModel.fromJson({
        'messageId': 'm1',
        'text': 'hi',
        'fromUserId': 'support',
        'createdAt': '2026-07-28T12:00:00.000Z',
        'updatedAt': '2026-07-28T12:00:00.000Z',
        'attachments': [
          {'attachmentId': 'a1', 'fileName': 'x.png'},
          {'fileType': 'image/png'},
        ],
      }, 'user-1');

      final mapped = BbxApiMapper.supportChatMessage(message);

      expect(mapped.isAdmin, isTrue);
      final attachment = mapped.attachments?.single;
      expect(attachment?.attachmentId, 'a1');
      expect(attachment?.messageId, 'm1');
    });

    test('an attachment carries its decoded bytes', () {
      final attachment = bbx.MessageAttachmentModel.fromJson({
        'attachmentId': 'a1',
        'fileName': 'x.txt',
        'fileData': 'aGk=',
      });

      final mapped = BbxApiMapper.supportChatAttachment(attachment);

      expect(mapped.fileData, Uint8List.fromList('hi'.codeUnits));
    });
  });

  test('order stats keep every series', () {
    final stats = bbx.OrderStatsResponseModel.fromJson({
      'orderStats': {
        'bitcoinBuyVolume': [
          {'currency': 'CAD', 'value': 10},
        ],
        'bitcoinBuyTradeCount': <dynamic>[],
        'averageBitcoinBuyPrice': <dynamic>[],
        'bitcoinSellVolume': <dynamic>[],
        'bitcoinSellTradeCount': <dynamic>[],
        'averageBitcoinSellPrice': <dynamic>[],
        'totalBitcoinTradingVolume': <dynamic>[],
        'buySellRatio': '1:0',
      },
      'billerStats': {
        'currency': 'CAD',
        'stats': [
          {
            'billerName': 'Hydro',
            'billerCode': 'H1',
            'totalAmount': 5,
            'tradeCount': 2,
          },
        ],
      },
      'asOf': '2026-07-28T12:00:00.000Z',
    });

    final mapped = BbxApiMapper.orderStats(stats);

    expect(mapped.orderStats.bitcoinBuyVolume.single.value, 10);
    expect(mapped.orderStats.buySellRatio, '1:0');
    expect(mapped.billerStats.stats.single.displayName, 'Hydro - H1');
    expect(mapped.asOf, DateTime.utc(2026, 7, 28, 12));
  });

  test('a default wallet recipient maps type, address and flag', () {
    final recipient = bbx.RecipientModel.fromJson({
      'recipientId': 'r1',
      'recipientType': 'OUT_LIQUID_ADDRESS',
      'address': 'lq1example',
      'isDefault': true,
    });

    final wallet = BbxApiMapper.defaultWallet(recipient);

    expect(
      wallet,
      const DefaultWallet(
        recipientId: 'r1',
        walletType: WalletAddressType.liquid,
        address: 'lq1example',
      ),
    );
  });

  test('a user summary without payjoinReceiveEnabled has payjoin off', () {
    final mapped = BbxApiMapper.userSummary(
      bbx.UserSummaryModel.fromJson(
        _userSummaryJson()..remove('payjoinReceiveEnabled'),
      ),
    );

    expect(mapped.payjoinReceiveEnabled, isFalse);
  });

  test('a default wallet falls back to the per-network address fields', () {
    WalletAddressType? type;
    String addressOf(Map<String, dynamic> json) {
      final wallet = BbxApiMapper.defaultWallet(
        bbx.RecipientModel.fromJson({'recipientId': 'r1', ...json}),
      );
      type = wallet.walletType;
      return wallet.address;
    }

    expect(
      addressOf({
        'recipientType': 'OUT_BITCOIN_ADDRESS',
        'bitcoinAddress': 'bc1qexample',
      }),
      'bc1qexample',
    );
    expect(type, WalletAddressType.bitcoin);
    expect(
      addressOf({
        'recipientType': 'OUT_LIGHTNING_ADDRESS',
        'lightningAddress': 'user@example.com',
      }),
      'user@example.com',
    );
    expect(
      addressOf({
        'recipientType': 'OUT_LIQUID_ADDRESS',
        'address': 'lq1first',
        'liquidAddress': 'lq1second',
      }),
      'lq1first',
    );
    expect(addressOf({'recipientType': 'OUT_LIQUID_ADDRESS'}), '');
  });

  test('values the app does not know map to unknown', () {
    final order = BbxApiMapper.orderFromSummary(
      bbx.OrderSummaryModel.fromJson({
        'orderId': 'o1',
        'orderType': 'Buy Gold Bars',
        'orderNumber': 1,
        'payinAmount': 1,
        'payinCurrency': 'USDT',
        'payoutAmount': 1,
        'payoutCurrency': 'CAD',
        'orderStatus': 'Failed',
        'payinStatus': 'Completed',
        'payoutMethod': 'Teleport',
        'payinMethod': 'CAD Balance',
        'triggerType': 'MANUAL',
        'createdAt': '2026-07-01T12:00:00.000Z',
      }, fallbacks: BbxApiSetup.orderSummaryParsing.fallbacks),
      isTestnet: false,
    );

    expect(order, isA<GenericOrder>());
    expect(order.orderType, OrderType.unknown);
    expect((order as GenericOrder).orderTypeName, 'Buy Gold Bars');
    expect(order.orderStatus, OrderStatus.unknown);
    expect(order.payinStatus, OrderPayinStatus.completed);
    expect(order.payoutStatus, OrderPayoutStatus.unknown);
    expect(order.payinMethod, OrderPaymentMethod.cadBalance);
    expect(order.payoutMethod, OrderPaymentMethod.unknown);
  });

  test('Sell USDT maps to a generic order of its own type', () {
    final order = BbxApiMapper.orderFromSummary(
      bbx.OrderSummaryModel.fromJson({
        'orderId': 'o1',
        'orderType': 'Sell USDT',
        'orderNumber': 1,
        'payinAmount': 1,
        'payinCurrency': 'USDT',
        'payoutAmount': 1,
        'payoutCurrency': 'CAD',
        'orderStatus': 'Completed',
        'payinStatus': 'Completed',
        'payoutStatus': 'Completed',
        'payoutMethod': 'CAD Balance',
        'payinMethod': 'CAD Balance',
        'createdAt': '2026-07-01T12:00:00.000Z',
      }, fallbacks: BbxApiSetup.orderSummaryParsing.fallbacks),
      isTestnet: false,
    );

    expect(order, isA<GenericOrder>());
    expect(order.orderType, OrderType.sellUsdt);
  });
}

Map<String, dynamic> _userSummaryJson() => <String, dynamic>{
  'userNumber': 42,
  'userId': 'user-1',
  'groups': ['KYC_IDENTITY_VERIFIED', 'JURI_EU'],
  'profile': {'firstName': 'Test', 'lastName': 'User'},
  'email': 'test.user@example.com',
  'balances': [
    {'amount': 10.5, 'currencyCode': 'CAD'},
    {'amount': 0, 'currencyCode': 'EUR'},
  ],
  'language': 'EN',
  'currency': 'CAD',
  'emailNotificationsEnabled': false,
  'payjoinReceiveEnabled': true,
  'twoFaEnabled': false,
  'dca': {
    'isActive': true,
    'frequency': 'DAILY',
    'amount': 20,
    'address': 'bc1qexample',
    'recipientType': 'OUT_BITCOIN_ADDRESS',
    'currencyCode': 'EUR',
  },
  'autoBuy': {
    'isActive': true,
    'addresses': {'bitcoin': 'bc1qexample', 'liquid': 'lq1example'},
  },
  'kycDocumentStatus': {
    'secureFileUpload': 'UNDER_REVIEW',
    'documents': {
      'id': 'ACCEPTED',
      'proofOfResidence': 'REJECTED',
      'selfie': 'NOT_UPLOADED',
    },
  },
};
