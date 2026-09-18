import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../nostr_identity/fixtures/backup_credential_vectors.dart';

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

void main() {
  final seed = Seed.bytes(
    bytes: backupCredentialVectorSeed,
    masterFingerprint: 'aabbccdd',
  );

  late NostrIdentityFacade identities;
  setUp(() {
    final defaults = _DefaultSeed();
    final settings = _Settings();
    when(() => settings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => defaults.execute(environment: Environment.mainnet),
    ).thenAnswer((_) async => seed);
    identities = NostrIdentityFacade(
      BackupCredentialResolver(getDefaultSeed: defaults, getSettings: settings),
    );
  });

  test(
    'the manifest interprets the two recorded backup chains on the words root',
    () async {
      final credential = BackupCredential.fromSeed(seed);
      final records =
          (await GetBackupIdentitiesUsecase(identities).execute()
                  as Ok<List<BackupIdentityRecord>, KeychainManifestFailure>)
              .value;
      final reveal = RevealBackupIdentityUsecase(identities);
      Future<String> nsec(BackupIdentityRecord record) async =>
          (await reveal.execute(record)
                  as Ok<RevealedNostrSecret, KeychainManifestFailure>)
              .value
              .nsec;
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
      expect(await nsec(records.first), startsWith('nsec1'));
      expect(await nsec(records.first), isNot(await nsec(records.last)));
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
          parentFingerprint: seed.masterFingerprint,
          publicKey: backupCredentialVectorServerPublicKey,
          derivationSteps: steps,
        ),
        throwsFormatException,
      );
    }
    final record = BackupIdentityRecord.fromInstruction(
      parentFingerprint: seed.masterFingerprint,
      publicKey: backupCredentialVectorServerPublicKey,
      derivationSteps: Bip85Reservations.backupServerIdentityChain,
    );
    expect(record.kind, BackupIdentityKind.server);
    final mismatched = BackupIdentityRecord(
      parentFingerprint: seed.masterFingerprint,
      publicKey: '0' * 64,
      kind: BackupIdentityKind.server,
    );
    expect(
      await RevealBackupIdentityUsecase(identities).execute(mismatched),
      isA<Err>(),
    );
  });
}
