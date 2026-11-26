import 'package:bull_exchange/src/limit_orders/domain/limit_destination_failure.dart';
import 'package:bull_exchange/src/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/payment_request.dart';

Matcher _refused() => isA<Err<Destination, Failure>>().having(
  (e) => e.failure,
  'failure',
  isA<LimitDestinationFailure>(),
);

void main() {
  test('an empty text is no address and is never parsed', () async {
    final parsed = <String>[];
    final answer = await ValidateLightningAddressUsecase(
      parse: (data) async {
        parsed.add(data);
        throw Exception();
      },
    ).execute('  ');
    expect(answer, _refused());
    expect(parsed, isEmpty);
  });

  test(
    'a parser failure is no address; a programmer error is thrown',
    () async {
      expect(
        await ValidateLightningAddressUsecase(
          parse: (_) async => throw Exception(),
        ).execute('x'),
        _refused(),
      );
      await expectLater(
        ValidateLightningAddressUsecase(
          parse: (_) async => throw StateError('bug'),
        ).execute('x'),
        throwsStateError,
      );
    },
  );

  test('a Lightning address is taken trimmed; any other payment string '
      'is refused', () async {
    final parsed = <String>[];
    final usecase = ValidateLightningAddressUsecase(
      parse: (data) async {
        parsed.add(data);
        return data.contains('@')
            ? LnAddressPaymentRequest(address: data)
            : const BitcoinPaymentRequest(address: 'bc1q', isTestnet: false);
      },
    );
    expect(
      await usecase.execute('  satoshi@getalby.com '),
      isA<Ok<Destination, Failure>>().having(
        (o) => o.value,
        'value',
        isA<DestinationAddress>()
            .having((d) => d.rail, 'rail', BtcNetwork.lightning)
            .having((d) => d.address, 'address', 'satoshi@getalby.com'),
      ),
    );
    expect(await usecase.execute('bc1q'), _refused());
    expect(parsed, ['satoshi@getalby.com', 'bc1q']);
  });
}
