import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  GetDcaDefaultWalletsUsecase usecaseWith(
    Future<Result<DefaultWallets, ExchangeFailure>> Function() read,
  ) => GetDcaDefaultWalletsUsecase(
    exchange: exchangeForTesting(getDefaultWallets: read),
  );

  test('returns the exchange default wallets', () async {
    const wallets = DefaultWallets(
      bitcoin: DefaultWallet(
        walletType: WalletAddressType.bitcoin,
        address: 'tb1qdefault',
      ),
    );
    final usecase = usecaseWith(() async => const Ok(wallets));

    final result = await usecase.execute();

    expect(result, isA<Ok<DefaultWallets, DcaFailure>>());
    expect((result as Ok<DefaultWallets, DcaFailure>).value, wallets);
  });

  test('maps a refused session to AccountUnavailable', () async {
    final usecase = usecaseWith(
      () async => const Err(ExchangeSessionRejectedFailure()),
    );

    final result = await usecase.execute();

    expect(result, isA<Err<DefaultWallets, DcaFailure>>());
    expect(
      (result as Err<DefaultWallets, DcaFailure>).failure,
      isA<DcaAccountUnavailableFailure>(),
    );
  });

  test('maps a failed read to AccountUnavailable, not to an empty set '
      'of wallets', () async {
    final usecase = usecaseWith(
      () async => const Err(ExchangeNetworkFailure('HTTP 500')),
    );

    final result = await usecase.execute();

    expect(result, isA<Err<DefaultWallets, DcaFailure>>());
    expect(
      (result as Err<DefaultWallets, DcaFailure>).failure,
      isA<DcaAccountUnavailableFailure>(),
    );
  });

  test('rethrows an Error', () async {
    final usecase = usecaseWith(() async => throw StateError('bug'));

    expect(usecase.execute, throwsA(isA<StateError>()));
  });
}
