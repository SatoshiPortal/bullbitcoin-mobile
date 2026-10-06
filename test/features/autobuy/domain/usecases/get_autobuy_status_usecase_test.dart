import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_status.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

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
    usecase = GetAutoBuyStatusUsecase(getUserSummary);
  });

  test('reports an active, unrestricted account', () async {
    when(
      () => getUserSummary.execute(),
    ).thenAnswer((_) async => _summary(autoBuyActive: true));

    final status =
        (await usecase.execute() as Ok<AutoBuyStatus, AutoBuyFailure>).value;

    expect(status.isActive, isTrue);
    expect(status.isRestricted, isFalse);
  });

  test('reports the funding restriction from the account groups', () async {
    when(() => getUserSummary.execute()).thenAnswer(
      (_) async => _summary(
        autoBuyActive: false,
        groups: ['KYC_IDENTITY_VERIFIED', 'RESTRICTED_FULL'],
      ),
    );

    final status =
        (await usecase.execute() as Ok<AutoBuyStatus, AutoBuyFailure>).value;

    expect(status.isActive, isFalse);
    expect(status.isRestricted, isTrue);
  });

  test('maps an unavailable account to a typed failure', () async {
    when(
      () => getUserSummary.execute(),
    ).thenThrow(GetExchangeUserSummaryException('account request failed'));

    final result = await usecase.execute();

    expect(
      (result as Err<AutoBuyStatus, AutoBuyFailure>).failure,
      isA<AutoBuyAccountUnavailableFailure>(),
    );
  });

  test('maps an unclassified account error to the catch-all', () async {
    when(
      () => getUserSummary.execute(),
    ).thenThrow(Exception('something nobody classified'));

    final result = await usecase.execute();

    expect(
      (result as Err<AutoBuyStatus, AutoBuyFailure>).failure,
      isA<AutoBuyUnexpectedFailure>(),
    );
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => getUserSummary.execute()).thenThrow(StateError('bug'));

    expect(() => usecase.execute(), throwsStateError);
  });
}
