import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_account_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/expire_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Access extends Mock implements ExchangeAccessRepository {}

class _Account extends Mock implements ExchangeAccountRepository {}

class _Settings extends Mock implements SettingsRepository {}

class _Expire extends Mock implements ExpireExchangeSessionUsecase {}

void main() {
  late _Access access;
  late _Account mainnet;
  late _Account testnet;
  late _Settings settings;
  late _Expire expire;
  late GetExchangeAccountUsecase usecase;
  var epoch = 1;
  setUp(() {
    epoch = 1;
    access = _Access();
    mainnet = _Account();
    testnet = _Account();
    settings = _Settings();
    expire = _Expire();
    when(
      () => access.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    when(() => access.epoch).thenAnswer((_) => epoch);
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => expire.execute(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    usecase = GetExchangeAccountUsecase(
      mainnetAccountRepository: mainnet,
      testnetAccountRepository: testnet,
      settingsRepository: settings,
      access: access,
      expire: expire,
    );
  });

  test('current server rejection expires the matching epoch', () async {
    when(
      mainnet.getAccount,
    ).thenAnswer((_) async => const Err(ExchangeSessionRejectedFailure()));
    expect(await usecase.execute(), isA<Err<UserSummary, ExchangeFailure>>());
    verify(() => expire.execute(epoch: 1, isTestnet: false)).called(1);
  });

  test('old server rejection cannot expire a newer session', () async {
    final pending = Completer<Result<UserSummary, ExchangeFailure>>();
    when(mainnet.getAccount).thenAnswer((_) => pending.future);
    final result = usecase.execute();
    await Future<void>.delayed(Duration.zero);
    epoch++;
    pending.complete(const Err(ExchangeSessionRejectedFailure()));
    expect((await result as Err).failure, isA<ExchangeOperationStaleFailure>());
    verifyNever(
      () => expire.execute(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  });

  for (final failure in <ExchangeFailure>[
    const ExchangeNotAuthenticatedFailure(),
    const ExchangeAccountUnavailableFailure(),
    const ExchangeNetworkFailure(),
  ]) {
    test('$failure does not expire a credential', () async {
      when(mainnet.getAccount).thenAnswer((_) async => Err(failure));
      expect((await usecase.execute() as Err).failure, same(failure));
      verifyNever(
        () => expire.execute(
          epoch: any(named: 'epoch'),
          isTestnet: any(named: 'isTestnet'),
        ),
      );
    });
  }

  test('signed out access does not read the account or expire', () async {
    when(
      () => access.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
    expect(
      (await usecase.execute() as Err).failure,
      isA<ExchangeNotAuthenticatedFailure>(),
    );
    verifyZeroInteractions(mainnet);
    verifyNever(
      () => expire.execute(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  });

  test('settings read failure is reported without an account call', () async {
    when(settings.fetch).thenThrow(Exception('locked'));
    final result = await usecase.execute();
    expect((result as Err).failure, isA<ExchangeAccountUnavailableFailure>());
    verifyZeroInteractions(mainnet);
    verifyNever(
      () => expire.execute(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  });

  test('testnet uses the testnet account repository', () async {
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
      ),
    );
    when(
      testnet.getAccount,
    ).thenAnswer((_) async => const Err(ExchangeAccountUnavailableFailure()));
    await usecase.execute();
    verify(testnet.getAccount).called(1);
    verifyZeroInteractions(mainnet);
  });
}
