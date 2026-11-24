import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_failure.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_status.dart';
import 'package:bull_exchange/src/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetExchangeUserSummaryUsecase extends Mock
    implements _SummaryReader {}

abstract interface class _SummaryReader {
  Future<Result<UserSummary, ExchangeFailure>> execute();
}

UserSummary _summary({
  required bool autoBuyActive,
  List<String> groups = const ['KYC_IDENTITY_VERIFIED'],
}) => UserSummary(
  userNumber: 1,
  groups: groups,
  profile: const UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
  email: 'satoshi@example.com',
  balances: const [],
  language: 'FR',
  currency: 'CAD',
  dca: const UserDca(isActive: false),
  autoBuy: UserAutoBuy(
    isActive: autoBuyActive,
    addresses: const UserAutoBuyAddresses(),
  ),
  emailNotificationsEnabled: false,
);

void main() {
  late MockGetExchangeUserSummaryUsecase getUserSummary;
  late GetAutoBuyStatusUsecase usecase;

  setUp(() {
    getUserSummary = MockGetExchangeUserSummaryUsecase();
    usecase = GetAutoBuyStatusUsecase(
      exchangeForTesting(getUserSummary: (_) => getUserSummary.execute()),
    );
  });

  test('reports an active, unrestricted account', () async {
    when(() => getUserSummary.execute())
        .thenAnswer((_) async => Ok(_summary(autoBuyActive: true)));

    final status =
        (await usecase.execute() as Ok<AutoBuyStatus, AutoBuyFailure>).value;

    expect(status.isActive, isTrue);
    expect(status.isRestricted, isFalse);
  });

  test('reports the funding restriction from the account groups', () async {
    when(() => getUserSummary.execute()).thenAnswer(
      (_) async => Ok(
        _summary(
          autoBuyActive: false,
          groups: ['KYC_IDENTITY_VERIFIED', 'RESTRICTED_FULL'],
        ),
      ),
    );

    final status =
        (await usecase.execute() as Ok<AutoBuyStatus, AutoBuyFailure>).value;

    expect(status.isActive, isFalse);
    expect(status.isRestricted, isTrue);
  });

  test('maps an unavailable account to a typed failure', () async {
    when(() => getUserSummary.execute())
        .thenAnswer((_) async => const Err(ExchangeNotAuthenticatedFailure()));

    final result = await usecase.execute();

    expect(
      (result as Err<AutoBuyStatus, AutoBuyFailure>).failure,
      isA<AutoBuyAccountUnavailableFailure>(),
    );
  });

  test('maps a failed account query to an unavailable account', () async {
    when(() => getUserSummary.execute())
        .thenAnswer((_) async => const Err(ExchangeNetworkFailure()));

    final result = await usecase.execute();

    expect(
      (result as Err<AutoBuyStatus, AutoBuyFailure>).failure,
      isA<AutoBuyAccountUnavailableFailure>(),
    );
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => getUserSummary.execute()).thenThrow(StateError('bug'));

    expect(() => usecase.execute(), throwsStateError);
  });
}
