import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import '../../../nostr_identity/fixtures/backup_secret_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../nostr_identity/fixtures/backup_credential_vectors.dart';

class _Identities extends Mock implements NostrIdentityFacade {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Secret seed;
  late BackupCredential credential;
  late _Identities identities;
  setUp(() async {
    seed = await backupSecretFixture();
    credential =
        (await seed.backup.data() as Ok<BackupCredential, SecretFailure>).value;
    identities = _Identities();
    when(identities.resolve).thenAnswer((_) async => Ok(credential));
  });

  test(
    'the manifest interprets the two recorded backup chains on the words root',
    () async {
      final records =
          (await GetBackupIdentitiesUsecase(identities).execute()
                  as Ok<List<BackupIdentityRecord>, KeychainManifestFailure>)
              .value;
      expect(records.map((record) => record.publicKey), [
        credential.artifactPublicKey,
        credential.serverPublicKey,
      ]);
      expect(
        records.first.derivationSteps,
        Bip85Reservations.backupArtifactIdentityChain,
      );
      expect(
        records.last.derivationSteps,
        Bip85Reservations.backupServerIdentityChain,
      );
      expect(records.first.publicKey, isNot(records.last.publicKey));
    },
  );

  test('only the two live, bounded backup chains can be claimed', () async {
    for (final steps in [
      <String>[],
      <String>[Bip85Reservations.backupServerIdentityPath],
      <String>[
        ...Bip85Reservations.backupServerIdentityChain,
        Bip85Reservations.backupServerIdentityPath,
      ],
      <String>["39'/0'/12'/99'", Bip85Reservations.backupServerIdentityPath],
    ]) {
      expect(
        () => BackupIdentityRecord.fromInstruction(
          parentFingerprint: seed.id.hex,
          publicKey: backupCredentialVectorServerPublicKey,
          derivationSteps: steps,
        ),
        throwsFormatException,
      );
    }
    final record = BackupIdentityRecord.fromInstruction(
      parentFingerprint: seed.id.hex,
      publicKey: backupCredentialVectorServerPublicKey,
      derivationSteps: Bip85Reservations.backupServerIdentityChain,
    );
    expect(record.kind, BackupIdentityKind.server);
  });
}
