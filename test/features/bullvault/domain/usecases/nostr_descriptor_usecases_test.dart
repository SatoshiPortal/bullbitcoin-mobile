import 'dart:convert';

import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_repository.dart';
import 'package:bb_mobile/features/bullvault/data/vault_descriptor_publication_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/vault_descriptor_publication.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/discover_descriptors_on_nostr_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/publish_descriptor_to_nostr_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/verify_nostr_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bullvault_test_fixture.dart';
import '../../support/fake_nostr_relay.dart';

const _words =
    'abandon differ wave love claim impact beach put bunker polar fragile crop';
const _otherWords =
    'smoke merit develop rug defy when swallow pink raven negative twin glass';

final class _FakeRepository extends Fake implements BullVaultRepository {
  final Map<String, BullVaultRecord> records = {};
  BullVaultFailure? readFailure;

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  ) async => readFailure == null ? Ok(records[walletId]) : Err(readFailure!);
}

/// The credential this device owns, or none at all.
final class _FakeIdentity extends Fake implements NostrIdentityFacade {
  _FakeIdentity({this.words = _words});

  final String? words;
  int calls = 0;

  @override
  Future<Result<BackupCredential, NostrIdentityFailure>>
  backupCredential() async {
    calls++;
    final available = words;
    return available == null
        ? const Err(NostrIdentityUnavailableFailure())
        : Ok(BackupCredential.fromWords(available));
  }
}

void main() {
  late List<FakeNostrRelay> relays;
  late _FakeRepository repository;
  late _FakeIdentity identity;
  late SqliteDatabase database;
  late VaultDescriptorPublicationRepository publications;
  late NostrDescriptorRepository nostr;
  late PublishDescriptorToNostrUsecase publish;
  late DiscoverDescriptorsOnNostrUsecase discover;
  late VerifyNostrDescriptorBackupUsecase verify;

  BullVaultRecord vault({
    String walletId = 'vault-wallet',
    BullVaultLifecycleStatus status = BullVaultLifecycleStatus.active,
    bool includesInheritance = false,
  }) => testBullVaultCreateResult(
    walletId: walletId,
    status: status,
    includesInheritance: includesInheritance,
    network: Network.bitcoinTestnet,
  ).record;

  setUp(() {
    relays = [
      FakeNostrRelay('wss://one.example'),
      FakeNostrRelay('wss://two.example'),
    ];
    repository = _FakeRepository();
    identity = _FakeIdentity();
    database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    publications = VaultDescriptorPublicationRepository(
      database,
      now: () => DateTime.utc(2027, 5, 5),
    );
    nostr = NostrDescriptorRepository(
      const RecoverBullEncryption(),
      NostrRelayDatasource(
        connect: fakeRelayNetwork(relays),
        timeout: const Duration(milliseconds: 500),
      ),
      relays: relays.map((relay) => relay.uri).toList(),
      now: () => DateTime.utc(2027, 5, 5),
    );
    publish = PublishDescriptorToNostrUsecase(
      repository,
      publications,
      identity,
      nostr,
    );
    discover = DiscoverDescriptorsOnNostrUsecase(identity, nostr);
    verify = VerifyNostrDescriptorBackupUsecase(repository, discover);
  });

  /// The stored row for one destination, or null when there is none.
  Future<VaultDescriptorPublication?> row(
    String walletId,
    VaultBackupDestination destination,
  ) async =>
      (await publications.load(walletId)
              as Ok<List<VaultDescriptorPublication>, BullVaultFailure>)
          .value
          .where((stored) => stored.destination == destination)
          .firstOrNull;

  /// Publishes and asserts it landed, for the arrangements below.
  Future<void> published(String walletId) async => expect(
    await publish.execute(walletId),
    isA<Ok<NostrDescriptorPublication, BullVaultFailure>>(),
  );

  group('publish', () {
    test('an active vault reaches every relay under its own author', () async {
      final record = vault();
      repository.records[record.walletId] = record;

      final result = await publish.execute(record.walletId);

      expect(result, isA<Ok<NostrDescriptorPublication, BullVaultFailure>>());
      final publication =
          (result as Ok<NostrDescriptorPublication, BullVaultFailure>).value;
      expect(publication.accepted, isTrue);
      expect(
        publication.outcomes.values,
        everyElement(NostrRelayOutcome.accepted),
      );
      for (final relay in relays) {
        expect(relay.events.single['id'], publication.eventId);
        expect(
          relay.events.single['pubkey'],
          BackupCredential.fromWords(_words).nostrPublicKeyHex,
        );
      }
    });

    test(
      'a migrating vault still publishes, a pending one never does',
      () async {
        for (final status in BullVaultLifecycleStatus.values) {
          final record = vault(walletId: status.name, status: status);
          repository.records[record.walletId] = record;
          for (final relay in relays) {
            relay.events.clear();
            relay.publications = 0;
          }

          final result = await publish.execute(record.walletId);

          switch (status) {
            case BullVaultLifecycleStatus.active:
            case BullVaultLifecycleStatus.migrating:
              expect(
                result,
                isA<Ok<Object?, BullVaultFailure>>(),
                reason: status.name,
              );
              expect(relays.first.publications, 1);
            case BullVaultLifecycleStatus.pending:
            case BullVaultLifecycleStatus.cancelled:
              expect(
                result,
                isA<Err<Object?, BullVaultFailure>>(),
                reason: status.name,
              );
              expect(relays.first.publications, 0, reason: status.name);
          }
        }
      },
    );

    test(
      'a pending vault publishes once its descriptor is confirmed',
      () async {
        final record = vault(
          status: BullVaultLifecycleStatus.pending,
        ).copyWith(recoveryPackageConfirmed: true);
        repository.records[record.walletId] = record;

        expect(
          await publish.execute(record.walletId),
          isA<Ok<NostrDescriptorPublication, BullVaultFailure>>(),
        );
        expect(relays.first.publications, 1);
      },
    );

    test(
      'an unknown vault and a storage failure never reach a relay',
      () async {
        expect(
          await publish.execute('nobody'),
          isA<Err<NostrDescriptorPublication, BullVaultFailure>>(),
        );
        repository.readFailure = const BullVaultBackupStatusFailure();
        expect(
          await publish.execute('nobody'),
          isA<Err<NostrDescriptorPublication, BullVaultFailure>>(),
        );
        expect(relays.first.publications, 0);
        expect(identity.calls, 0);
      },
    );

    test('a device with no credential publishes nothing', () async {
      final record = vault();
      repository.records[record.walletId] = record;
      publish = PublishDescriptorToNostrUsecase(
        repository,
        publications,
        _FakeIdentity(words: null),
        nostr,
      );

      final result = await publish.execute(record.walletId);

      expect(
        result,
        isA<Err<NostrDescriptorPublication, BullVaultFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<BullVaultBackupCredentialFailure>(),
        ),
      );
      expect(relays.first.publications, 0);
    });

    test('every relay refusing leaves the vault without a route', () async {
      final record = vault();
      repository.records[record.walletId] = record;
      for (final relay in relays) {
        relay.rejects = true;
      }

      expect(
        await publish.execute(record.walletId),
        isA<Err<NostrDescriptorPublication, BullVaultFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<BullVaultNostrUnreachableFailure>(),
        ),
      );
    });

    test('the signed event is written down before it is sent', () async {
      final record = vault();
      repository.records[record.walletId] = record;

      await published(record.walletId);

      final stored = await row(record.walletId, VaultBackupDestination.nostr);
      expect(stored!.state, VaultPublicationState.sent);
      expect(stored.attempts, 1);
      expect(
        jsonDecode(utf8.decode(stored.artifact!)),
        relays.first.events.single,
        reason: 'the bytes on the relay are the bytes on disk',
      );
      expect(
        stored.artifactSha256,
        sha256.convert(stored.artifact!).toString(),
      );
    });

    test('a retry resends the identical event, never a second one', () async {
      final record = vault();
      repository.records[record.walletId] = record;
      for (final relay in relays) {
        relay.unreachable = true;
      }

      expect(
        await publish.execute(record.walletId),
        isA<Err<NostrDescriptorPublication, BullVaultFailure>>(),
      );
      final pending = await row(record.walletId, VaultBackupDestination.nostr);
      expect(pending!.state, VaultPublicationState.failed);
      expect(pending.outstanding, isFalse, reason: 'not selected yet');

      for (final relay in relays) {
        relay.unreachable = false;
      }
      await published(record.walletId);

      final sent = await row(record.walletId, VaultBackupDestination.nostr);
      expect(sent!.state, VaultPublicationState.sent);
      expect(sent.attempts, 2);
      expect(sent.artifact, pending.artifact, reason: 'the same bytes');
      expect(
        relays.first.events.single['id'],
        jsonDecode(utf8.decode(pending.artifact!))['id'],
      );
    });

    test('a stored event from another credential is never replaced', () async {
      final record = vault();
      repository.records[record.walletId] = record;
      await published(record.walletId);
      final original = await row(record.walletId, VaultBackupDestination.nostr);

      // The same vault, now on a phone whose backup words are different.
      publish = PublishDescriptorToNostrUsecase(
        repository,
        publications,
        _FakeIdentity(words: _otherWords),
        nostr,
      );
      final result = await publish.execute(record.walletId);

      expect(
        result,
        isA<Err<NostrDescriptorPublication, BullVaultFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<BullVaultForeignBackupCredentialFailure>(),
        ),
      );
      final kept = await row(record.walletId, VaultBackupDestination.nostr);
      expect(kept!.artifact, original!.artifact);
      expect(
        relays.first.events,
        hasLength(1),
        reason: 'a foreign credential never re-keys a published descriptor',
      );
    });

    test('acceptance is not retention, so it is not verification', () async {
      final record = vault();
      repository.records[record.walletId] = record;
      for (final relay in relays) {
        relay.forgets = true;
      }

      final published = await publish.execute(record.walletId);
      final verified = await verify.execute(record.walletId);

      expect(
        published,
        isA<Ok<NostrDescriptorPublication, BullVaultFailure>>(),
      );
      expect(
        (verified as Ok<NostrDescriptorVerification, BullVaultFailure>)
            .value
            .found,
        isFalse,
      );
    });
  });

  group('discover', () {
    test('supplied words search without ever asking for a seed', () async {
      final record = vault();
      repository.records[record.walletId] = record;
      await published(record.walletId);
      final callsBefore = identity.calls;

      final result = await discover.execute(words: _words);

      expect(identity.calls, callsBefore, reason: 'no seed was consulted');
      final search =
          (result as Ok<NostrDescriptorSearch, BullVaultFailure>).value;
      expect(
        search.descriptors.single.descriptor,
        record.recoveryPackage.policy.descriptor,
      );
      expect(search.descriptors.single.network, Network.bitcoinTestnet);
      expect(search.incomplete, isFalse);
    });

    test(
      'words that are not the twelve-word form never reach a relay',
      () async {
        for (final input in ['', 'abandon abandon', 'x' * 300, 'not words']) {
          expect(
            await discover.execute(words: input),
            isA<Err<NostrDescriptorSearch, BullVaultFailure>>().having(
              (error) => error.failure,
              'failure',
              isA<BullVaultBackupWordsFailure>(),
            ),
            reason: input,
          );
        }
        expect(relays.first.subscriptions, 0);
      },
    );

    test('a device with no credential and no words cannot search', () async {
      discover = DiscoverDescriptorsOnNostrUsecase(
        _FakeIdentity(words: null),
        nostr,
      );

      expect(
        await discover.execute(),
        isA<Err<NostrDescriptorSearch, BullVaultFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<BullVaultBackupCredentialFailure>(),
        ),
      );
      expect(relays.first.subscriptions, 0);
    });

    test('a cancelled search stops and says so', () async {
      final result = await discover.execute(session: NostrSession()..cancel());

      final search =
          (result as Ok<NostrDescriptorSearch, BullVaultFailure>).value;
      expect(search.descriptors, isEmpty);
      expect(search.incomplete, isTrue);
    });
  });

  group('verify', () {
    test('only this vault\'s own descriptor certifies it', () async {
      final mine = vault(walletId: 'mine');
      final other = vault(walletId: 'other', includesInheritance: true);
      repository.records
        ..[mine.walletId] = mine
        ..[other.walletId] = other;
      await published(other.walletId);

      final result = await verify.execute(mine.walletId);

      final verified =
          (result as Ok<NostrDescriptorVerification, BullVaultFailure>).value;
      expect(verified.found, isFalse);
      expect(verified.incomplete, isFalse);

      await published(mine.walletId);
      expect(
        (await verify.execute(mine.walletId)
                as Ok<NostrDescriptorVerification, BullVaultFailure>)
            .value
            .found,
        isTrue,
      );
    });

    test('an unfinished search is carried through', () async {
      final record = vault();
      repository.records[record.walletId] = record;
      await published(record.walletId);
      relays.first.unreachable = true;

      final verified =
          (await verify.execute(record.walletId)
                  as Ok<NostrDescriptorVerification, BullVaultFailure>)
              .value;

      expect(verified.found, isTrue);
      expect(verified.incomplete, isTrue);
    });

    test('an unknown vault is never certified', () async {
      expect(
        await verify.execute('nobody'),
        isA<Err<NostrDescriptorVerification, BullVaultFailure>>(),
      );
      expect(relays.first.subscriptions, 0);
    });
  });
}
