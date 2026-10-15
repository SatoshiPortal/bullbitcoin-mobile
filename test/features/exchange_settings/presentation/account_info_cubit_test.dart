import 'package:bb_mobile/features/exchange_settings/domain/entities/account_info.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_account_info_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/account_info_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetAccountInfo extends Mock implements GetAccountInfoUsecase {}

const _accountInfo = AccountInfo(
  userNumber: 7,
  email: 'sat@example.com',
  firstName: 'Sat',
  lastName: 'Oshi',
  verificationLevel: VerificationLevel.light,
);

void main() {
  late _MockGetAccountInfo getAccountInfo;

  setUp(() => getAccountInfo = _MockGetAccountInfo());

  test('a successful load holds the account info', () async {
    when(
      getAccountInfo.execute,
    ).thenAnswer((_) async => const Ok(_accountInfo));
    final cubit = AccountInfoCubit(getAccountInfoUsecase: getAccountInfo);
    addTearDown(cubit.close);

    await cubit.loadAccountInfo();

    expect(cubit.state.accountInfo, _accountInfo);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.failure, isNull);
  });

  test('a failed load holds the failure', () async {
    when(getAccountInfo.execute).thenAnswer(
      (_) async => const Err(ExchangeSettingsAccountUnavailableFailure()),
    );
    final cubit = AccountInfoCubit(getAccountInfoUsecase: getAccountInfo);
    addTearDown(cubit.close);

    await cubit.loadAccountInfo();

    expect(cubit.state.accountInfo, isNull);
    expect(cubit.state.isLoading, isFalse);
    expect(
      cubit.state.failure,
      isA<ExchangeSettingsAccountUnavailableFailure>(),
    );
  });

  test('a retry clears the previous failure', () async {
    when(getAccountInfo.execute).thenAnswer(
      (_) async => const Err(ExchangeSettingsAccountUnavailableFailure()),
    );
    final cubit = AccountInfoCubit(getAccountInfoUsecase: getAccountInfo);
    addTearDown(cubit.close);
    await cubit.loadAccountInfo();

    when(
      getAccountInfo.execute,
    ).thenAnswer((_) async => const Ok(_accountInfo));
    await cubit.loadAccountInfo();

    expect(cubit.state.failure, isNull);
    expect(cubit.state.accountInfo, _accountInfo);
  });
}
