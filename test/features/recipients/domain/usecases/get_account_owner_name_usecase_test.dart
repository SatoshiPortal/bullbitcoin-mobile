import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/account_owner_name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

void main() {
  late _MockGetExchangeUserSummaryUsecase summary;

  setUp(() => summary = _MockGetExchangeUserSummaryUsecase());

  test('reads the legal name on the exchange account', () async {
    when(() => summary.execute()).thenAnswer(
      (_) async => const UserSummary(
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
    );

    final result = await GetAccountOwnerNameUsecase(summary).execute();

    final name = (result as Ok<AccountOwnerName, RecipientsFailure>).value;
    expect(name.firstName, 'Mary Ann');
    expect(name.lastName, 'Smith');
    expect(name.fullName, 'Mary Ann Smith');
  });

  test('an unreadable user summary is a failure', () async {
    when(() => summary.execute()).thenThrow(Exception('401 unauthenticated'));

    final result = await GetAccountOwnerNameUsecase(summary).execute();

    expect(
      (result as Err<AccountOwnerName, RecipientsFailure>).failure,
      isA<RecipientsUnexpectedFailure>(),
    );
  });
}
