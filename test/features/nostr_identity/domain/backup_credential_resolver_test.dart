import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/backup_credential_vectors.dart';

class _DefaultSeed extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

void main() {
  test(
    'the resolver uses Ben selection in the active environment on each operation',
    () async {
      final defaults = _DefaultSeed();
      final settings = _Settings();
      var environment = Environment.testnet;
      when(() => settings.execute()).thenAnswer(
        (_) async => SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      final seed = Seed.bytes(
        bytes: backupCredentialVectorSeed,
        masterFingerprint: 'fixture',
      );
      for (final env in Environment.values) {
        when(
          () => defaults.execute(environment: env),
        ).thenAnswer((_) async => seed);
      }
      final resolver = BackupCredentialResolver(
        getDefaultSeed: defaults,
        getSettings: settings,
      );
      for (final env in [Environment.testnet, Environment.mainnet]) {
        environment = env;
        final result = await resolver.resolve();
        expect(
          (result as Ok<BackupCredential, NostrIdentityFailure>)
              .value
              .serverPublicKey,
          backupCredentialVectorServerPublicKey,
        );
        verify(() => defaults.execute(environment: env)).called(1);
      }
    },
  );

  test(
    'words-only recovery does not require a local default seed or settings',
    () {
      final resolver = BackupCredentialResolver(
        getDefaultSeed: _DefaultSeed(),
        getSettings: _Settings(),
      );
      final result = resolver.fromWords(backupCredentialVectorWords);
      expect(
        (result as Ok<BackupCredential, NostrIdentityFailure>)
            .value
            .artifactPublicKey,
        backupCredentialVectorNostrPublicKey,
      );
    },
  );

  test(
    'new-boundary failures contain neither underlying exceptions nor input',
    () async {
      final settings = _Settings();
      when(
        () => settings.execute(),
      ).thenThrow(Exception('private fixture details'));
      final resolver = BackupCredentialResolver(
        getDefaultSeed: _DefaultSeed(),
        getSettings: settings,
      );
      final unavailable = await resolver.resolve();
      expect(
        (unavailable as Err<BackupCredential, NostrIdentityFailure>).failure,
        isA<BackupCredentialUnavailable>(),
      );
      expect(unavailable.failure.logMessage, isNull);
      final invalid = resolver.fromWords('private fixture input');
      expect(
        (invalid as Err<BackupCredential, NostrIdentityFailure>).failure,
        isA<InvalidDataRecoveryWords>(),
      );
      expect(invalid.failure.logMessage, isNull);
    },
  );
}
