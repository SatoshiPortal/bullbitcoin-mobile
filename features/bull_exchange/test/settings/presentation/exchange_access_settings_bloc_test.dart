import 'dart:async';

import 'package:bull_exchange/src/settings/domain/manage_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/presentation/exchange_access_settings_bloc.dart';
import 'package:bull_exchange/src/settings/domain/exchange_access_settings_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Watch extends Mock implements WatchExchangeAccessUsecase {}

class _Set extends Mock implements ManageExchangeAccessUsecase {}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Watch watch;
  late _Set set;
  late StreamController<ExchangeAccess> changes;
  late ExchangeAccess current;
  late ExchangeAccessSettingsBloc bloc;

  setUp(() {
    watch = _Watch();
    set = _Set();
    changes = StreamController<ExchangeAccess>();
    current = const ExchangeAccessDisabled();
    when(() => watch.current).thenAnswer((_) => current);
    when(watch.execute).thenAnswer((_) => changes.stream);
    bloc = ExchangeAccessSettingsBloc(watch, set);
  });
  tearDown(() async {
    await bloc.close();
    await changes.close();
  });

  test('a second tap while the first attempt runs sends nothing', () async {
    final pending = Completer<Result<void, ExchangeFailure>>();
    when(() => set.execute(true)).thenAnswer((_) => pending.future);
    bloc.add(const AccessSettingsEnableRequested());
    await _settle();
    expect(bloc.state, isA<AccessSettingsWorking>());
    bloc
      ..add(const AccessSettingsSignOutRequested())
      ..add(const AccessSettingsEnableRequested());
    await _settle();
    verify(() => set.execute(true)).called(1);
    verifyNever(() => set.execute(false));
    current = const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet);
    pending.complete(const Ok(null));
    await _settle();
    expect(
      bloc.state,
      const AccessSettingsSucceeded(
        ExchangeAccessSignedOut(ExchangeEnvironment.mainnet),
        ExchangeAccessAttempt.enable,
      ),
    );
  });

  test(
    'an unfinished sign-out refuses enabling and retries sign-out',
    () async {
      changes.add(const ExchangeAccessSignOutIncomplete());
      await _settle();
      when(() => set.execute(false)).thenAnswer((_) async => const Ok(null));
      bloc.add(const AccessSettingsEnableRequested());
      await _settle();
      verifyNever(() => set.execute(true));
      bloc.add(const AccessSettingsSignOutRequested());
      await _settle();
      await _settle();
      verify(() => set.execute(false)).called(1);
      expect(bloc.state, isA<AccessSettingsSucceeded>());
    },
  );

  test(
    'a failure stays with its attempt until access changes (INT-15)',
    () async {
      when(() => set.execute(false))
          .thenAnswer((_) async => const Err(ExchangeSessionClearFailure()));
      bloc.add(const AccessSettingsSignOutRequested());
      await _settle();
      await _settle();
      expect(
        bloc.state,
        const AccessSettingsFailed(
          ExchangeAccessDisabled(),
          ExchangeAccessAttempt.signOut,
          ExchangeSessionClearFailure(),
        ),
      );
      changes.add(const ExchangeAccessSignOutIncomplete());
      await _settle();
      expect(
        bloc.state,
        const AccessSettingsIdle(ExchangeAccessSignOutIncomplete()),
      );
    },
  );

  test('retry resolves access', () async {
    when(set.retry).thenAnswer((_) async => const Ok(null));
    bloc.add(const AccessSettingsRetryRequested());
    await _settle();
    await _settle();
    verify(set.retry).called(1);
    expect(
      bloc.state,
      const AccessSettingsSucceeded(
        ExchangeAccessDisabled(),
        ExchangeAccessAttempt.retry,
      ),
    );
  });
}
