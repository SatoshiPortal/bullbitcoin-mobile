import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/limit_orders/data/datasources/limit_orders_api_datasource.dart';
import 'package:bb_mobile/features/limit_orders/data/limit_order_repository_impl.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order.dart';
import 'package:bb_mobile/features/limit_orders/domain/limit_orders_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLimitOrdersApiDatasource extends Mock
    implements LimitOrdersApiDatasource {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockLimitOrdersApiDatasource mainnet;
  late MockLimitOrdersApiDatasource testnet;
  late MockSettingsRepository settingsRepository;
  late LimitOrderRepositoryImpl repository;

  LimitOrdersFailure failureOf(
    Result<List<LimitOrder>, LimitOrdersFailure> r,
  ) => (r as Err<List<LimitOrder>, LimitOrdersFailure>).failure;

  void useEnvironment({required bool isTestnet}) {
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => SettingsEntity(
        environment: isTestnet ? Environment.testnet : Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
  }

  setUp(() {
    mainnet = MockLimitOrdersApiDatasource();
    testnet = MockLimitOrdersApiDatasource();
    settingsRepository = MockSettingsRepository();
    repository = LimitOrderRepositoryImpl(mainnet, testnet, settingsRepository);
    useEnvironment(isTestnet: false);
  });

  test('routes to the testnet datasource on testnet', () async {
    useEnvironment(isTestnet: true);
    when(() => testnet.listActive()).thenAnswer((_) async => []);

    await repository.listActive();

    verify(() => testnet.listActive()).called(1);
    verifyNever(() => mainnet.listActive());
  });

  test('maps the maximum-active API code to its own failure', () async {
    when(
      () => mainnet.listActive(),
    ).thenThrow(const LimitOrdersApiException(code: 'ERR_ORDTRG_LOMAX429'));

    expect(
      failureOf(await repository.listActive()),
      isA<LimitOrdersMaximumActiveFailure>(),
    );
  });

  test('maps the not-found API code to its own failure', () async {
    when(
      () => mainnet.get(any()),
    ).thenThrow(const LimitOrdersApiException(code: 'ERR_ORDTRG_LO404'));

    final result = await repository.get('lo-1');

    expect(
      (result as Err<LimitOrder, LimitOrdersFailure>).failure,
      isA<LimitOrderNotFoundFailure>(),
    );
  });

  test('maps an unknown API code to the operation fallback', () async {
    when(
      () => mainnet.listActive(),
    ).thenThrow(const LimitOrdersApiException(code: 'ERR_SOMETHING_NEW'));

    expect(
      failureOf(await repository.listActive()),
      isA<LimitOrdersLoadFailure>(),
    );
  });

  test('maps a 401 to an unavailable account', () async {
    when(() => mainnet.listActive()).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      ),
    );

    expect(
      failureOf(await repository.listActive()),
      isA<LimitOrdersAccountUnavailableFailure>(),
    );
  });

  test('maps an unclassified exception to the catch-all', () async {
    when(() => mainnet.listActive()).thenThrow(Exception('socket died'));

    expect(
      failureOf(await repository.listActive()),
      isA<LimitOrdersUnexpectedFailure>(),
    );
  });

  test('does not convert programmer errors into recoverable failures', () {
    when(() => mainnet.listActive()).thenThrow(StateError('bug'));

    expect(() => repository.listActive(), throwsStateError);
  });
}
