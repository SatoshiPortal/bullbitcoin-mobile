import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_activation_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../recipient_fixtures.dart';

class _MockVirtualIbanRepository extends Mock
    implements VirtualIbanRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockVirtualIbanRepository repository;
  late _MockSettingsRepository settings;
  late WatchVirtualIbanActivationUsecase usecase;

  setUp(() {
    repository = _MockVirtualIbanRepository();
    settings = _MockSettingsRepository();
    when(() => settings.fetch()).thenAnswer((_) async => settingsFixture());
    usecase = WatchVirtualIbanActivationUsecase(
      repository,
      settings,
      Duration.zero,
    );
  });

  test('does not create an absent account during the initial check', () async {
    when(
      () => repository.getStatus(isTestnet: false),
    ).thenAnswer((_) async => const Ok(VirtualIbanStatus.absent));

    final results = await usecase.execute(createIfAbsent: false).toList();

    expect(
      (results.single as Ok<VirtualIbanStatus, RecipientsFailure>).value,
      VirtualIbanStatus.absent,
    );
    verifyNever(() => repository.create(isTestnet: false));
  });

  test('creates and polls an account until active', () async {
    when(
      () => repository.getStatus(isTestnet: false),
    ).thenAnswer((_) async => const Ok(VirtualIbanStatus.absent));
    when(
      () => repository.create(isTestnet: false),
    ).thenAnswer((_) async => const Ok(VirtualIbanStatus.active));

    final results = await usecase.execute(createIfAbsent: true).toList();

    expect(
      (results.single as Ok<VirtualIbanStatus, RecipientsFailure>).value,
      VirtualIbanStatus.active,
    );
    verify(() => repository.create(isTestnet: false)).called(1);
  });
}
