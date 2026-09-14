import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/vault_descriptor_publication_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/vault_descriptor_publication.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late String path;
  late SqliteDatabase database;
  late VaultDescriptorPublicationRepository repository;

  final artifact = Uint8List.fromList(List.generate(512, (i) => i % 251));
  final other = Uint8List.fromList(List.filled(64, 3));

  SqliteDatabase open() => SqliteDatabase(NativeDatabase(File(path)));

  setUp(() {
    directory = Directory.systemTemp.createTempSync('vault_publications');
    path = p.join(directory.path, 'publications.sqlite');
    database = open();
    repository = VaultDescriptorPublicationRepository(
      database,
      now: () => DateTime.utc(2027, 2, 3, 4, 5, 6),
    );
  });

  tearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });

  /// Every write in an arrangement must succeed for it to mean anything.
  Future<void> ok(Future<Result<void, BullVaultFailure>> write) async =>
      expect(await write, isA<Ok<void, BullVaultFailure>>());

  Future<List<VaultDescriptorPublication>> rows(
    VaultDescriptorPublicationRepository from,
    String walletId,
  ) async =>
      (await from.load(walletId)
              as Ok<List<VaultDescriptorPublication>, BullVaultFailure>)
          .value;

  Future<VaultDescriptorPublication> single(
    VaultDescriptorPublicationRepository from,
    String walletId,
    VaultBackupDestination destination,
  ) async => (await rows(
    from,
    walletId,
  )).firstWhere((row) => row.destination == destination);

  test('a vault with no choices has no rows', () async {
    expect(await rows(repository, 'vault'), isEmpty);
  });

  test('a prepared artifact is stored byte for byte with its hash', () async {
    await ok(
      repository.prepare(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
        artifact: artifact,
      ),
    );

    final stored = await single(
      repository,
      'vault',
      VaultBackupDestination.nostr,
    );
    expect(stored.artifact, orderedEquals(artifact));
    expect(stored.artifactSha256, sha256.convert(artifact).toString());
    expect(stored.state, VaultPublicationState.pending);
    expect(stored.attempts, 0);
    expect(stored.enabled, isFalse);
    expect(stored.updatedAt, DateTime.utc(2027, 2, 3, 4, 5, 6));
  });

  test('the same bytes come back after the database is reopened', () async {
    await ok(
      repository.prepare(
        walletId: 'vault',
        destination: VaultBackupDestination.server,
        artifact: artifact,
      ),
    );
    await ok(
      repository.setEnabled(
        walletId: 'vault',
        destination: VaultBackupDestination.server,
        enabled: true,
      ),
    );
    await ok(
      repository.markFailed(
        walletId: 'vault',
        destination: VaultBackupDestination.server,
      ),
    );
    await database.close();

    database = open();
    final reopened = VaultDescriptorPublicationRepository(database);
    final stored = await single(
      reopened,
      'vault',
      VaultBackupDestination.server,
    );

    expect(stored.artifact, orderedEquals(artifact));
    expect(stored.state, VaultPublicationState.failed);
    expect(stored.attempts, 1);
    expect(stored.enabled, isTrue);
    expect(stored.outstanding, isTrue, reason: 'a retry still owes this send');
  });

  test('a send counts as an attempt and a read-back does not', () async {
    await ok(
      repository.prepare(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
        artifact: artifact,
      ),
    );

    await ok(
      repository.markFailed(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
      ),
    );
    await ok(
      repository.markSent(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
      ),
    );
    expect(
      (await single(
        repository,
        'vault',
        VaultBackupDestination.nostr,
      )).attempts,
      2,
    );

    await ok(
      repository.markVerified(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
      ),
    );
    final verified = await single(
      repository,
      'vault',
      VaultBackupDestination.nostr,
    );
    expect(verified.state, VaultPublicationState.verified);
    expect(verified.attempts, 2);
    expect(verified.outstanding, isFalse);
  });

  test('only an explicit prepare replaces the artifact', () async {
    await ok(
      repository.prepare(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
        artifact: artifact,
      ),
    );
    await ok(
      repository.markSent(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
      ),
    );
    await ok(
      repository.setEnabled(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
        enabled: true,
      ),
    );

    expect(
      (await single(
        repository,
        'vault',
        VaultBackupDestination.nostr,
      )).artifact,
      orderedEquals(artifact),
    );

    await ok(
      repository.prepare(
        walletId: 'vault',
        destination: VaultBackupDestination.nostr,
        artifact: other,
      ),
    );
    final replaced = await single(
      repository,
      'vault',
      VaultBackupDestination.nostr,
    );
    expect(replaced.artifact, orderedEquals(other));
    expect(replaced.state, VaultPublicationState.pending);
    expect(replaced.attempts, 0);
    expect(replaced.enabled, isTrue, reason: 'the choice is the person\'s');
  });

  test('turning a destination off keeps what was already sent', () async {
    await ok(
      repository.prepare(
        walletId: 'vault',
        destination: VaultBackupDestination.server,
        artifact: artifact,
      ),
    );
    await ok(
      repository.markSent(
        walletId: 'vault',
        destination: VaultBackupDestination.server,
      ),
    );
    await ok(
      repository.setEnabled(
        walletId: 'vault',
        destination: VaultBackupDestination.server,
        enabled: false,
      ),
    );

    final stored = await single(
      repository,
      'vault',
      VaultBackupDestination.server,
    );
    expect(stored.artifact, orderedEquals(artifact));
    expect(stored.state, VaultPublicationState.sent);
    expect(stored.outstanding, isFalse, reason: 'nothing owes a disabled row');
  });

  test('destinations and vaults do not share a row', () async {
    await ok(
      repository.prepare(
        walletId: 'one',
        destination: VaultBackupDestination.nostr,
        artifact: artifact,
      ),
    );
    await ok(
      repository.prepare(
        walletId: 'one',
        destination: VaultBackupDestination.server,
        artifact: other,
      ),
    );
    await ok(
      repository.prepare(
        walletId: 'two',
        destination: VaultBackupDestination.nostr,
        artifact: other,
      ),
    );
    await ok(
      repository.markSent(
        walletId: 'one',
        destination: VaultBackupDestination.nostr,
      ),
    );

    final one = await rows(repository, 'one');
    expect(one.map((row) => row.destination), [
      VaultBackupDestination.nostr,
      VaultBackupDestination.server,
    ]);
    expect(one.first.state, VaultPublicationState.sent);
    expect(one.last.state, VaultPublicationState.pending);
    expect(await rows(repository, 'two'), hasLength(1));
  });

  test('a row a newer build wrote is dropped, not guessed at', () async {
    await database.customStatement(
      'INSERT INTO vault_descriptor_publications '
      '(wallet_id, destination, enabled, state, attempts, updated_at) '
      "VALUES ('vault', 'opreturn', 1, 'pending', 0, 0), "
      "('vault', 'nostr', 1, 'reconciling', 0, 0)",
    );

    expect(await rows(repository, 'vault'), isEmpty);
  });
}
