import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/update_payjoin_expire_after_sec_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository repository;
  late UpdatePayjoinExpireAfterSecUsecase usecase;

  setUp(() {
    repository = _MockSettingsRepository();
    usecase = UpdatePayjoinExpireAfterSecUsecase(
      settingsRepository: repository,
    );
    when(
      () => repository.setPayjoinExpireAfterSec(any()),
    ).thenAnswer((_) async {});
  });

  test('persists the given expiry via the settings repository', () async {
    await usecase.execute(payjoinExpireAfterSec: 120);

    verify(() => repository.setPayjoinExpireAfterSec(120)).called(1);
  });
}
