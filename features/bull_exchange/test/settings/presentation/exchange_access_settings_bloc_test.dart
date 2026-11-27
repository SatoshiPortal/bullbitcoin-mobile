import 'dart:async';

import 'package:bull_exchange/src/settings/domain/exchange_access_settings_state.dart';
import 'package:bull_exchange/src/settings/domain/exchange_access_settings_event.dart';
import 'package:bull_exchange/src/settings/presentation/exchange_access_settings_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../settings_usecase_fakes.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late StreamController<ExchangeAccess> changes;
  late ExchangeAccess current;
  late List<String> calls;

  ExchangeAccessSettingsBloc build({
    AccessAnswer? enable,
    AccessAnswer? signOut,
    AccessAnswer? resolve,
  }) {
    final bloc = accessSettingsBloc(
      current: () => current,
      changes: changes.stream,
      calls: calls,
      enable: enable,
      signOut: signOut,
      resolve: resolve,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  setUp(() {
    changes = StreamController<ExchangeAccess>();
    current = const ExchangeAccessDisabled();
    calls = [];
  });
  tearDown(() => changes.close());

  test('a second tap while the first attempt runs sends nothing', () async {
    final pending = Completer<Result<void, ExchangeFailure>>();
    final bloc = build(enable: () => pending.future);
    bloc.add(const AccessSettingsEnableRequested());
    await _settle();
    expect(bloc.state, isA<AccessSettingsWorking>());
    bloc
      ..add(const AccessSettingsSignOutRequested())
      ..add(const AccessSettingsEnableRequested());
    await _settle();
    expect(calls, ['enable']);
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
      final bloc = build(signOut: () async => const Ok(null));
      changes.add(const ExchangeAccessSignOutIncomplete());
      await _settle();
      bloc.add(const AccessSettingsEnableRequested());
      await _settle();
      expect(calls, isEmpty);
      bloc.add(const AccessSettingsSignOutRequested());
      await _settle();
      await _settle();
      expect(calls, ['signOut']);
      expect(bloc.state, isA<AccessSettingsSucceeded>());
    },
  );

  test(
    'a failure stays with its attempt until access changes (INT-15)',
    () async {
      final bloc = build(
        signOut: () async => const Err(ExchangeSessionClearFailure()),
      );
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
    final bloc = build(resolve: () async => const Ok(null));
    bloc.add(const AccessSettingsRetryRequested());
    await _settle();
    await _settle();
    expect(calls, ['resolve']);
    expect(
      bloc.state,
      const AccessSettingsSucceeded(
        ExchangeAccessDisabled(),
        ExchangeAccessAttempt.retry,
      ),
    );
  });
}
