import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

/// The shared core use-case stringifies its cause, so its message carries
/// whatever the exchange API or Dio produced.
const _rawReason =
    'DioException [bad response]: {"error":{"message":"apikey=secret123"}}';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

const _summary = UserSummary(
  userNumber: 1,
  groups: ['KYC_IDENTITY_VERIFIED'],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

void main() {
  late _MockGetExchangeUserSummaryUsecase core;
  late GetFundExchangeUserSummaryUsecase usecase;

  setUp(() {
    core = _MockGetExchangeUserSummaryUsecase();
    usecase = GetFundExchangeUserSummaryUsecase(
      getExchangeUserSummaryUsecase: core,
    );
  });

  test('wraps a successful summary in Ok', () async {
    when(core.execute).thenAnswer((_) async => _summary);

    final result = await usecase.execute();

    expect((result as Ok).value, _summary);
  });

  test('converts the foreign exception into a sanitized failure', () async {
    when(core.execute).thenThrow(GetExchangeUserSummaryException(_rawReason));

    final result = await usecase.execute();

    expect(result, isA<Err<UserSummary, FundExchangeFailure>>());
    final failure = (result as Err).failure as FundExchangeFailure;
    expect(failure, isA<FundExchangeUnexpectedFailure>());
    expect(
      failure.logMessage,
      isNot(contains('secret123')),
      reason: 'only the exception runtimeType is kept, never its message',
    );
  });

  test('never rethrows, whatever the core use-case throws', () async {
    when(core.execute).thenThrow(StateError(_rawReason));

    await expectLater(usecase.execute(), completes);
    expect(
      ((await usecase.execute()) as Err).failure,
      isA<FundExchangeUnexpectedFailure>(),
    );
  });
}
