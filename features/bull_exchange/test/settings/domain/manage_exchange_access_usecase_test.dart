import 'package:bull_exchange/src/settings/domain/manage_exchange_access_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('activation failure does not block explicit session cleanup', () async {
    var signOuts = 0;
    final usecase = ManageExchangeAccessUsecase((
      current: () => const ExchangeAccessUnreadable(),
      watch: () => const Stream.empty(),
      enable: () async => const Err(ExchangeUnexpectedFailure()),
      signOut: () async {
        signOuts++;
        return const Ok(null);
      },
      resolve: () async => const Ok(null),
    ));

    expect(await usecase.execute(true), isA<Err<void, ExchangeFailure>>());
    expect(signOuts, 0);
    expect(await usecase.execute(false), const Ok<void, ExchangeFailure>(null));
    expect(signOuts, 1);
  });

  test('preserves cleanup errors without attempting activation', () async {
    final usecase = ManageExchangeAccessUsecase((
      current: () => const ExchangeAccessSignOutIncomplete(),
      watch: () => const Stream.empty(),
      enable: () async => fail('unexpected activation'),
      signOut: () async => const Err(ExchangeSessionClearFailure()),
      resolve: () async => const Ok(null),
    ));

    expect(
      await usecase.execute(false),
      isA<Err<void, ExchangeFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ExchangeSessionClearFailure>(),
      ),
    );
  });
}
