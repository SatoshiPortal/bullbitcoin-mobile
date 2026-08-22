import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart' as payjoin;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' as primitives;

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

  setUp(() {
    payjoinPolicy = _MockPayjoinPolicyAccess();
    getDisclaimerShown = _MockGetPayjoinDisclaimerShownUsecase();
    markDisclaimerShown = _MockMarkPayjoinDisclaimerShownUsecase();
    when(() => payjoinPolicy.setEnabled(any())).thenAnswer((invocation) async {
      final enabled = invocation.positionalArguments.single as bool;
      return primitives.Ok(
        payjoin.PayjoinPolicy(
          enabled: enabled,
          tradingEnabled: true,
          minimumAmount: primitives.Sats.fromInt(10000),
          sessionLifetime: const Duration(hours: 24),
        ),
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
      false,
      requestConsent: () async {
        requestedConsent = true;
        return true;
      },
    );

    expect((result as Ok<bool, SettingsFailure>).value, isFalse);
    expect(requestedConsent, isFalse);
    verify(() => payjoinPolicy.setEnabled(false)).called(1);
    verifyNever(() => getDisclaimerShown.execute());
  });

  test('returns a settings failure when policy persistence fails', () async {
    when(() => payjoinPolicy.setEnabled(false)).thenAnswer(
      (_) async => const primitives.Err(
        payjoin.PayjoinStorageFailure('storage unavailable'),
      ),
    );

    final result = await usecase.execute(
      false,
      requestConsent: () async => true,
    );

    expect(result, isA<Err<bool, SettingsFailure>>());
  });

  test('enables immediately when consent was previously recorded', () async {
    var requestedConsent = false;

    final result = await usecase.execute(
      true,
      requestConsent: () async {
        requestedConsent = true;
        return true;
      },
    );

    expect((result as Ok<bool, SettingsFailure>).value, isTrue);
    expect(requestedConsent, isFalse);
    verify(() => payjoinPolicy.setEnabled(true)).called(1);
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('requests consent before enabling, then records it', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    final calls = <String>[];
    when(() => payjoinPolicy.setEnabled(true)).thenAnswer((_) async {
      calls.add('persist');
      return primitives.Ok(
        payjoin.PayjoinPolicy(
          enabled: true,
          tradingEnabled: true,
          minimumAmount: primitives.Sats.fromInt(10000),
          sessionLifetime: const Duration(hours: 24),
        ),
      );
    });
    when(() => markDisclaimerShown.execute()).thenAnswer((_) async {
      calls.add('mark');
      return const Ok<void, SettingsFailure>(null);
    });

    final result = await usecase.execute(
      true,
      requestConsent: () async {
        calls.add('consent');
        return true;
      },
    );

    expect((result as Ok<bool, SettingsFailure>).value, isTrue);
    expect(calls, ['consent', 'persist', 'mark']);
  });

  test('does not enable or mark when consent is not granted', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));

    final result = await usecase.execute(
      true,
      requestConsent: () async => false,
    );

    expect((result as Ok<bool, SettingsFailure>).value, isFalse);
    verifyNever(() => payjoinPolicy.setEnabled(any()));
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('does not consume consent when enabling fails', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    when(() => payjoinPolicy.setEnabled(true)).thenAnswer(
      (_) async => const primitives.Err(payjoin.PayjoinStorageFailure()),
    );

    final result = await usecase.execute(
      true,
      requestConsent: () async => true,
    );

    expect(result, isA<Err<bool, SettingsFailure>>());
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('fails closed when the consent flag cannot be read', () async {
    when(() => getDisclaimerShown.execute()).thenAnswer(
      (_) async => const Err<bool, SettingsFailure>(SettingsStorageFailure()),
    );

    final result = await usecase.execute(
      true,
      requestConsent: () async => true,
    );

    expect(result, isA<Err<bool, SettingsFailure>>());
    verifyNever(() => payjoinPolicy.setEnabled(any()));
  });

  test('keeps Payjoin enabled if recording consent fails', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    when(() => markDisclaimerShown.execute()).thenAnswer(
      (_) async => const Err<void, SettingsFailure>(SettingsStorageFailure()),
    );

    final result = await usecase.execute(
      true,
      requestConsent: () async => true,
    );

    expect((result as Ok<bool, SettingsFailure>).value, isTrue);
    verify(() => payjoinPolicy.setEnabled(true)).called(1);
  });
}
