import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/disable_payjoin_receivers_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_payjoin_enabled_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockGetPayjoinDisclaimerShownUsecase extends Mock
    implements GetPayjoinDisclaimerShownUsecase {}

class _MockMarkPayjoinDisclaimerShownUsecase extends Mock
    implements MarkPayjoinDisclaimerShownUsecase {}

class _MockDisablePayjoinReceiversUsecase extends Mock
    implements DisablePayjoinReceiversUsecase {}

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockGetPayjoinDisclaimerShownUsecase getDisclaimerShown;
  late _MockMarkPayjoinDisclaimerShownUsecase markDisclaimerShown;
  late _MockDisablePayjoinReceiversUsecase disablePayjoinReceivers;
  late SetPayjoinEnabledUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    getDisclaimerShown = _MockGetPayjoinDisclaimerShownUsecase();
    markDisclaimerShown = _MockMarkPayjoinDisclaimerShownUsecase();
    disablePayjoinReceivers = _MockDisablePayjoinReceiversUsecase();
    when(
      () => settingsRepository.setPayjoinEnabled(any()),
    ).thenAnswer((_) async {});
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(true));
    when(
      () => markDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<void, SettingsFailure>(null));
    when(() => disablePayjoinReceivers.execute()).thenAnswer((_) async {});
    usecase = SetPayjoinEnabledUsecase(
      settingsRepository: settingsRepository,
      getPayjoinDisclaimerShownUsecase: getDisclaimerShown,
      markPayjoinDisclaimerShownUsecase: markDisclaimerShown,
      disablePayjoinReceiversUsecase: disablePayjoinReceivers,
    );
  });

  test('persists disabling without requesting consent', () async {
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
    verify(() => settingsRepository.setPayjoinEnabled(false)).called(1);
    verify(() => disablePayjoinReceivers.execute()).called(1);
    verifyNever(() => getDisclaimerShown.execute());
  });

  test('keeps the setting enabled if active receivers cannot stop', () async {
    when(
      () => disablePayjoinReceivers.execute(),
    ).thenThrow(StateError('fallback failed'));

    final result = await usecase.execute(
      false,
      requestConsent: () async => true,
    );

    expect(result, isA<Err<bool, SettingsFailure>>());
    expect(
      (result as Err<bool, SettingsFailure>).failure,
      isA<SettingsPayjoinFailure>(),
    );
    verifyNever(() => settingsRepository.setPayjoinEnabled(false));
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
    verify(() => settingsRepository.setPayjoinEnabled(true)).called(1);
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('requests consent before enabling, then records it', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    final calls = <String>[];
    when(() => settingsRepository.setPayjoinEnabled(true)).thenAnswer((
      _,
    ) async {
      calls.add('persist');
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
    verifyNever(() => settingsRepository.setPayjoinEnabled(any()));
    verifyNever(() => markDisclaimerShown.execute());
  });

  test('does not consume consent when enabling fails', () async {
    when(
      () => getDisclaimerShown.execute(),
    ).thenAnswer((_) async => const Ok<bool, SettingsFailure>(false));
    when(
      () => settingsRepository.setPayjoinEnabled(true),
    ).thenThrow(Exception('storage unavailable'));

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
    verifyNever(() => settingsRepository.setPayjoinEnabled(any()));
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
    verify(() => settingsRepository.setPayjoinEnabled(true)).called(1);
  });
}
