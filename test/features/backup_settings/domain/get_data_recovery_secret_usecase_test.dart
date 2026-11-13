import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_data_recovery_secret_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../nostr_identity/fixtures/backup_secret_fixture.dart';

class _Identities extends Mock implements NostrIdentityFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Secret seed;
  late _Identities identities;
  late GetDataRecoverySecretUsecase usecase;
  setUp(() async {
    seed = await backupSecretFixture();
    identities = _Identities();
    when(identities.defaultSecret).thenAnswer((_) async => Ok(seed));
    usecase = GetDataRecoverySecretUsecase(identities);
  });

  test('returns a handle only after checking the current origin', () async {
    final result = await usecase.execute(
      expectedFingerprint: seed.id.hex.toUpperCase(),
    );
    final value = (result as Ok<Secret, BackupSettingsFailure>).value;
    expect(value, same(seed));
    verify(identities.defaultSecret).called(1);
  });

  test(
    'a vault without a recorded origin never falls back to device words',
    () async {
      expect(
        await usecase.execute(forVault: true),
        isA<Err<Secret, BackupSettingsFailure>>(),
      );
      verifyNever(identities.defaultSecret);
    },
  );

  test(
    'rejects another seed even if the earlier public origin check passed',
    () async {
      expect(
        await usecase.execute(expectedFingerprint: '11223344'),
        isA<Err<Secret, BackupSettingsFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BackupSettingsWordsUnavailableFailure>(),
        ),
      );
    },
  );

  test(
    'global reveal needs no vault origin, but missing or locked seed fails',
    () async {
      expect(await usecase.execute(), isA<Ok<Secret, BackupSettingsFailure>>());
      when(
        identities.defaultSecret,
      ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
      expect(
        await usecase.execute(),
        isA<Err<Secret, BackupSettingsFailure>>(),
      );
    },
  );
}
