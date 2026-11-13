import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/manage_exchange_access_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _Exchange extends Mock implements ExchangeFacade {}

class _Settings extends Mock implements SettingsRepository {}

void main() {
  late _Exchange exchange;
  late _Settings settings;
  setUp(() {
    exchange = _Exchange();
    settings = _Settings();
  });

  test('iOS non-superuser cannot activate exchange', () async {
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        isSuperuser: false,
      ),
    );
    final usecase = SetSettingsExchangeAccessUsecase(
      exchange,
      settings,
      isIOS: () => true,
    );
    expect(await usecase.execute(true), isA<Err<void, SettingsFailure>>());
    verifyNever(() => exchange.enable());
  });

  test('iOS superuser can activate exchange', () async {
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        isSuperuser: true,
      ),
    );
    when(() => exchange.enable()).thenAnswer((_) async => const Ok(null));
    final usecase = SetSettingsExchangeAccessUsecase(
      exchange,
      settings,
      isIOS: () => true,
    );
    expect(await usecase.execute(true), isA<Ok<void, SettingsFailure>>());
    verify(() => exchange.enable()).called(1);
  });

  test(
    'failed iOS settings read reports a failure without activating',
    () async {
      when(settings.fetch).thenThrow(const FormatException('unavailable'));
      final usecase = SetSettingsExchangeAccessUsecase(
        exchange,
        settings,
        isIOS: () => true,
      );
      expect(await usecase.execute(true), isA<Err<void, SettingsFailure>>());
      verifyNever(() => exchange.enable());
      when(exchange.logout).thenAnswer((_) async => const Ok(null));
      expect(await usecase.execute(false), isA<Ok<void, SettingsFailure>>());
      verify(exchange.logout).called(1);
    },
  );

  test('logout failure remains visible to settings', () async {
    when(
      exchange.logout,
    ).thenAnswer((_) async => const Err(ExchangeSessionClearFailure()));
    final usecase = SetSettingsExchangeAccessUsecase(
      exchange,
      settings,
      isIOS: () => false,
    );
    expect(await usecase.execute(false), isA<Err<void, SettingsFailure>>());
    verify(exchange.logout).called(1);
  });
}
