import 'package:primitives/primitives.dart';
import 'package:settings/testing.dart';
import 'package:settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinDisclaimerRepository extends Mock
    implements PayjoinDisclaimerRepository {}

void main() {
  late _MockPayjoinDisclaimerRepository repository;

  setUp(() {
    repository = _MockPayjoinDisclaimerRepository();
  });

  test('get forwards the typed repository result', () async {
    const expected = Ok<bool, SettingsFailure>(true);
    when(() => repository.hasBeenShown()).thenAnswer((_) async => expected);
    final usecase = GetPayjoinDisclaimerShownUsecase(
      payjoinDisclaimerRepository: repository,
    );

    expect(await usecase.execute(), same(expected));
  });

  test('mark forwards a storage failure', () async {
    const expected = Err<void, SettingsFailure>(SettingsStorageFailure());
    when(() => repository.markShown()).thenAnswer((_) async => expected);
    final usecase = MarkPayjoinDisclaimerShownUsecase(
      payjoinDisclaimerRepository: repository,
    );

    expect(await usecase.execute(), same(expected));
  });
}
