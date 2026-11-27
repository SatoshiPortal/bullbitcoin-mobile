import 'package:bull_exchange/src/buy/domain/usecases/validate_buy_address_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('a valid address is an on-chain destination as the host gives '
      'it', () async {
    final asked = <String>[];
    final answer = await ValidateBuyAddressUsecase((raw) async {
      asked.add(raw);
      return 'bc1qexternal';
    }).execute(' BC1QEXTERNAL ');
    expect(
      (answer as Ok<Destination, Failure>).value,
      const DestinationAddress(BtcNetwork.bitcoin, 'bc1qexternal'),
    );
    expect(asked, [' BC1QEXTERNAL ']);
  });

  test('an address the host refuses is invalid', () async {
    final answer = await ValidateBuyAddressUsecase((_) async => null)
        .execute('nope');
    expect(
      answer,
      isA<Err<Destination, Failure>>().having(
        (e) => e.failure,
        'failure',
        isA<ExchangeDestinationInvalidFailure>(),
      ),
    );
  });
}
