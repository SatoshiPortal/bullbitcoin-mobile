import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart' as payjoin;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' as primitives;

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

/// The value an [Ok] carries; an [Err] fails the test, naming the failure.
T _valueOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

class _MockPayjoinPolicyAccess extends Mock
    implements payjoin.PayjoinPolicyAccess {}

class _MockGetPayjoinDisclaimerShownUsecase extends Mock
    implements GetPayjoinDisclaimerShownUsecase {}

class _MockMarkPayjoinDisclaimerShownUsecase extends Mock
    implements MarkPayjoinDisclaimerShownUsecase {}

void main() {
  late _MockPayjoinPolicyAccess payjoinPolicy;
  late _MockGetPayjoinDisclaimerShownUsecase getDisclaimerShown;
  late _MockMarkPayjoinDisclaimerShownUsecase markDisclaimerShown;
  late SetPayjoinEnabledUsecase usecase;

  setUpAll(() => registerFallbackValue(payjoin.PayjoinAction.receive));

  setUp(() {
    payjoinPolicy = _MockPayjoinPolicyAccess();
    getDisclaimerShown = _MockGetPayjoinDisclaimerShownUsecase();
    markDisclaimerShown = _MockMarkPayjoinDisclaimerShownUsecase();
    when(
      () =>
          payjoinPolicy.setActionEnabled(any(), enabled: any(named: 'enabled')),
    ).thenAnswer((invocation) async {
      final action =
          invocation.positionalArguments.single as payjoin.PayjoinAction;
      final enabled = invocation.namedArguments[#enabled] as bool;
      return primitives.Ok(
        payjoin.PayjoinPolicy.defaults().withAction(action, enabled: enabled),
      );
    });
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(true));
    when(
      () => markDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<void, SettingsFailure>(null));
    usecase = SetPayjoinEnabledUsecase(
      payjoinPolicy: payjoinPolicy,
      getPayjoinDisclaimerShownUsecase: getDisclaimerShown,
      markPayjoinDisclaimerShownUsecase: markDisclaimerShown,
    );
  });

  test('disables through package policy without requesting consent', () async {
    var requestedConsent = false;

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      false,
      requestConsent: () async {
        requestedConsent = true;
        return true;
      },
    );

    expect(_valueOf(result), isFalse);
    expect(requestedConsent, isFalse);
    verify(
      () => payjoinPolicy.setActionEnabled(
        payjoin.PayjoinAction.receive,
        enabled: false,
      ),
    ).called(1);
    verifyNever(() => getDisclaimerShown.execute());
  });

  test('returns a settings failure when policy persistence fails', () async {
    when(
      () => payjoinPolicy.setActionEnabled(
        payjoin.PayjoinAction.receive,
        enabled: false,
      ),
    ).thenAnswer(
      (_) async => const primitives.Err(
        payjoin.PayjoinStorageFailure('storage unavailable'),
      ),
    );

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      false,
      requestConsent: () async => true,
    );

    final failure = _failureOf(result);
    expect(failure, isA<SettingsStorageFailure>());
    // The package's own reason stays in the package's log, not in ours.
    expect(failure.logMessage, isNot(contains('storage unavailable')));
  });

  test('enables immediately when consent was previously recorded', () async {
    var requestedConsent = false;

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      true,
      requestConsent: () async {
        requestedConsent = true;
        return true;
      },
    );

    expect(_valueOf(result), isTrue);
    expect(requestedConsent, isFalse);
    verify(
      () => payjoinPolicy.setActionEnabled(
        payjoin.PayjoinAction.receive,
        enabled: true,
      ),
    ).called(1);
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('requests consent before enabling, then records it', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    final calls = <String>[];
    when(
      () => payjoinPolicy.setActionEnabled(
        payjoin.PayjoinAction.receive,
        enabled: true,
      ),
    ).thenAnswer((_) async {
      calls.add('persist');
      return primitives.Ok(
        payjoin.PayjoinPolicy.defaults().copyWith(receiveEnabled: true),
      );
    });
    when(() => markDisclaimerShown.execute()).thenAnswer((_) async {
      calls.add('mark');
      return const Ok<void, SettingsFailure>(null);
    });

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      true,
      requestConsent: () async {
        calls.add('consent');
        return true;
      },
    );

    expect(_valueOf(result), isTrue);
    expect(calls, ['consent', 'persist', 'mark']);
  });

  test('does not enable or mark when consent is not granted', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      true,
      requestConsent: () async => false,
    );

    expect(_valueOf(result), isFalse);
    verifyNever(
      () =>
          payjoinPolicy.setActionEnabled(any(), enabled: any(named: 'enabled')),
    );
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('does not consume consent when enabling fails', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    when(
      () => payjoinPolicy.setActionEnabled(
        payjoin.PayjoinAction.receive,
        enabled: true,
      ),
    ).thenAnswer(
      (_) async => const primitives.Err(payjoin.PayjoinStorageFailure()),
    );

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      true,
      requestConsent: () async => true,
    );

    expect(_failureOf(result), isA<SettingsStorageFailure>());
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('fails closed when the consent flag cannot be read', () async {
    when(() => getDisclaimerShown.execute()).thenAnswer(
      (_) async => const Err<bool, SettingsFailure>(SettingsStorageFailure()),
    );

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      true,
      requestConsent: () async => true,
    );

    expect(_failureOf(result), isA<SettingsStorageFailure>());
    verifyNever(
      () =>
          payjoinPolicy.setActionEnabled(any(), enabled: any(named: 'enabled')),
    );
  });

  test('keeps Payjoin enabled if recording consent fails', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    when(() => markDisclaimerShown.execute()).thenAnswer(
      (_) async => const Err<void, SettingsFailure>(SettingsStorageFailure()),
    );

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      true,
      requestConsent: () async => true,
    );

    expect(_valueOf(result), isTrue);
    verify(
      () => payjoinPolicy.setActionEnabled(
        payjoin.PayjoinAction.receive,
        enabled: true,
      ),
    ).called(1);
  });

  test('a consent dialog that throws is a consent failure, without the '
      'reason', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      true,
      requestConsent: () async => throw StateError('navigator detached'),
    );

    final failure = _failureOf(result);
    expect(failure, isA<SettingsConsentFailure>());
    expect(failure.logMessage, isNull);
    verifyNever(
      () =>
          payjoinPolicy.setActionEnabled(any(), enabled: any(named: 'enabled')),
    );
  });

  test('only receiving asks for consent', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    var requestedConsent = false;

    for (final action in [
      payjoin.PayjoinAction.send,
      payjoin.PayjoinAction.buy,
      payjoin.PayjoinAction.sell,
    ]) {
      final result = await usecase.execute(
        action,
        true,
        requestConsent: () async {
          requestedConsent = true;
          return true;
        },
      );

      expect(_valueOf(result), isTrue);
      verify(
        () => payjoinPolicy.setActionEnabled(action, enabled: true),
      ).called(1);
    }
    expect(requestedConsent, isFalse);
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('a policy that throws is the catch-all, with the type only', () async {
    when(
      () => payjoinPolicy.setActionEnabled(
        payjoin.PayjoinAction.receive,
        enabled: false,
      ),
    ).thenThrow(Exception('sqlite: disk I/O error at /data/user/0'));

    final result = await usecase.execute(
      payjoin.PayjoinAction.receive,
      false,
      requestConsent: () async => true,
    );

    final failure = _failureOf(result);
    expect(failure, isA<SettingsUnexpectedFailure>());
    expect(failure.logMessage, 'setActionEnabled threw: _Exception');
  });
}
