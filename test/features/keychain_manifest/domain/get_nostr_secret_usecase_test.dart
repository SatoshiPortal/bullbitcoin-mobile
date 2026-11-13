import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_nostr_secret_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../nostr_identity/fixtures/backup_secret_fixture.dart';

class _Identities extends Mock implements NostrIdentityFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only the current default secret can open a matching key record',
    () async {
      final secret = await backupSecretFixture();
      final identities = _Identities();
      final usecase = GetNostrSecretUsecase(identities);
      when(identities.defaultSecret).thenAnswer((_) async => Ok(secret));
      expect(
        await usecase.execute(expectedFingerprint: secret.id.hex),
        isA<Ok<Secret, KeychainManifestFailure>>(),
      );
      expect(
        await usecase.execute(expectedFingerprint: 'aabbccdd'),
        isA<Err<Secret, KeychainManifestFailure>>(),
      );
      when(
        identities.defaultSecret,
      ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
      expect(
        await usecase.execute(expectedFingerprint: secret.id.hex),
        isA<Err<Secret, KeychainManifestFailure>>(),
      );
    },
  );
}
