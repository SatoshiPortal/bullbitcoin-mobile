import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/payjoin_disclaimer_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_payjoin_disclaimer_shown_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/mark_payjoin_disclaimer_shown_usecase.dart';
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
