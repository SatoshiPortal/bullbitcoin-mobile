import 'package:primitives/primitives.dart' show Failure;
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_entry_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/pay/domain/get_pay_entry_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/sell/domain/get_sell_entry_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

typedef _Execute =
    Future<Result<Object, Failure>> Function(
      ExchangeFacade exchange,
      bool isIOS,
    );

void main() {
  final consumers =
      <
        ({String name, _Execute execute, List<Object> entries, Matcher failure})
      >[
        (
          name: 'buy',
          execute: (exchange, isIOS) =>
              GetBuyEntryUsecase(exchange).execute(isIOS: isIOS),
          entries: [BuyEntry.allowed, BuyEntry.signIn, BuyEntry.unavailable],
          failure: isA<BuyUnexpectedFailure>(),
        ),
        (
          name: 'sell',
          execute: (exchange, isIOS) =>
              GetSellEntryUsecase(exchange).execute(isIOS: isIOS),
          entries: [SellEntry.allowed, SellEntry.signIn, SellEntry.unavailable],
          failure: isA<SellUnexpectedFailure>(),
        ),
        (
          name: 'pay',
          execute: (exchange, isIOS) =>
              GetPayEntryUsecase(exchange).execute(isIOS: isIOS),
          entries: [PayEntry.allowed, PayEntry.signIn, PayEntry.unavailable],
          failure: isA<PayUnexpectedFailure>(),
        ),
      ];
  const sourceEntries = [
    ExchangeTradingEntry.allowed,
    ExchangeTradingEntry.authenticationRequired,
    ExchangeTradingEntry.unavailable,
  ];

  for (final consumer in consumers) {
    for (final isIOS in [false, true]) {
      for (var i = 0; i < sourceEntries.length; i++) {
        final source = sourceEntries[i];
        final expected = consumer.entries[i];
        test(
          '${consumer.name} maps ${source.name} and forwards isIOS=$isIOS',
          () async {
            final exchange = _Exchange();
            when(
              () => exchange.tradingEntry(isIOS: isIOS),
            ).thenAnswer((_) async => Ok(source));
            final result = await consumer.execute(exchange, isIOS);
            expect(
              result,
              isA<Ok<Object, Failure>>().having(
                (r) => r.value,
                'entry',
                expected,
              ),
            );
            verify(() => exchange.tradingEntry(isIOS: isIOS)).called(1);
          },
        );
      }
      test('${consumer.name} maps exchange failure for isIOS=$isIOS', () async {
        final exchange = _Exchange();
        when(
          () => exchange.tradingEntry(isIOS: isIOS),
        ).thenAnswer((_) async => const Err(ExchangeUnexpectedFailure()));
        final result = await consumer.execute(exchange, isIOS);
        expect(
          result,
          isA<Err<Object, Failure>>().having(
            (r) => r.failure,
            'failure',
            consumer.failure,
          ),
        );
        verify(() => exchange.tradingEntry(isIOS: isIOS)).called(1);
      });
    }
  }
}
