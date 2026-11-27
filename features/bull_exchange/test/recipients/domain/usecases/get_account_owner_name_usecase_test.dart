import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/entities/account_owner_name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements _SummaryReader {}

abstract interface class _SummaryReader {
  Future<Result<UserSummary, ExchangeFailure>> execute();
}

void main() {
  late _MockGetExchangeUserSummaryUsecase summary;

  setUp(() => summary = _MockGetExchangeUserSummaryUsecase());

  test('reads the legal name on the exchange account', () async {
    when(() => summary.execute()).thenAnswer(
      (_) async => const Ok(
        UserSummary(
          userNumber: 1,
          groups: [],
          profile: UserProfile(firstName: 'Mary Ann ', lastName: 'Smith'),
          email: 'satoshi@example.com',
          balances: [],
          currency: 'EUR',
          dca: UserDca(isActive: false),
          autoBuy: UserAutoBuy(
            isActive: false,
            addresses: UserAutoBuyAddresses(),
          ),
        ),
      ),
    );

    final result = await GetAccountOwnerNameUsecase(
      exchangeForTesting(getUserSummary: (_) => summary.execute()),
    ).execute();

    final name = (result as Ok<AccountOwnerName, ExchangeFailure>).value;
    expect(name.firstName, 'Mary Ann');
    expect(name.lastName, 'Smith');
    expect(name.fullName, 'Mary Ann Smith');
  });

  test('an unreadable user summary is a failure', () async {
    when(
      () => summary.execute(),
    ).thenAnswer((_) async => const Err(ExchangeAccountUnavailableFailure()));

    final result = await GetAccountOwnerNameUsecase(
      exchangeForTesting(getUserSummary: (_) => summary.execute()),
    ).execute();

    expect(
      (result as Err<AccountOwnerName, ExchangeFailure>).failure,
      isA<ExchangeUnexpectedFailure>(),
    );
  });
}
