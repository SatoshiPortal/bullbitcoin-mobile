import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/usecases/start_sell_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

void main() {
  late MockGetExchangeUserSummaryUsecase getUserSummary;
  late MockGetSettingsUsecase getSettings;
  late StartSellUsecase usecase;

  setUp(() {
    getUserSummary = MockGetExchangeUserSummaryUsecase();
    getSettings = MockGetSettingsUsecase();
    usecase = StartSellUsecase(
      getExchangeUserSummaryUsecase: getUserSummary,
      getSettingsUsecase: getSettings,
    );
  });

  group('StartSellUsecase', () {
    test(
      'maps a user-summary throw to SellUnexpectedFailure — raw in logMessage only, no leak',
      () async {
        when(
          () => getUserSummary.execute(),
        ).thenThrow(Exception('summary boom'));

        final result = await usecase.execute();

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellUnexpectedFailure>());
        expect(
          (failure as SellUnexpectedFailure).logMessage,
          contains('summary boom'),
        );
      },
    );
  });
}
