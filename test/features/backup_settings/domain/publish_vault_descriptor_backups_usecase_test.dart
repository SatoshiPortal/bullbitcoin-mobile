import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/publish_vault_descriptor_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/data/vault_descriptor_publication_repository.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _serverArtifact = Uint8List.fromList(List.generate(200, (i) => i % 97));

/// The vault feature as this composition sees it: real publication state, a
/// scripted relay publisher and a scripted sealer.
final class _FakeVaults extends Fake implements BullVaultFacade {
  _FakeVaults(this.publications);

  final VaultDescriptorPublicationRepository publications;

  /// The state writes in this fake stand in for the real feature's, which does
  /// surface a storage failure; here they simply have to land.
  Future<void> _write(Future<Result<void, BullVaultFailure>> operation) async {
    if (await operation case Err(:final failure)) throw StateError('$failure');
  }

  BullVaultFailure? sealFailure;

  /// A failure the relay publisher reports before it records any outcome of
  /// its own, as an unavailable credential does.
  BullVaultFailure? publishFailure;
  bool relaysAccept = true;
  int nostrPublications = 0;
  int preparations = 0;

  @override
  Future<Result<List<VaultDescriptorPublication>, BullVaultFailure>>
  descriptorPublications(String walletId) => publications.load(walletId);

  @override
  Future<Result<void, BullVaultFailure>> setDescriptorBackupDestination({
    required String walletId,
    required VaultBackupDestination destination,
    required bool enabled,
  }) => publications.setEnabled(
    walletId: walletId,
    destination: destination,
    enabled: enabled,
  );

  @override
  Future<Result<BullVaultDescriptorBackup, BullVaultFailure>>
  prepareServerDescriptorBackup(String walletId) async {
    preparations++;
    if (sealFailure != null) return Err(sealFailure!);
    final stored =
        (await publications.load(walletId)
                as Ok<List<VaultDescriptorPublication>, BullVaultFailure>)
            .value
            .where((row) => row.destination == VaultBackupDestination.server)
            .map((row) => row.artifact)
            .firstOrNull;
    if (stored == null) {
      await _write(
        publications.prepare(
          walletId: walletId,
          destination: VaultBackupDestination.server,
          artifact: _serverArtifact,
        ),
      );
    }
    return Ok(
      BullVaultDescriptorBackup(
        descriptor: 'wsh(sortedmulti(2,A,B))',
        network: Network.bitcoinTestnet,
        bytes: stored ?? _serverArtifact,
        recipients: const ['tpub-a'],
        lookupTokens: ['a' * 64],
      ),
    );
  }

  @override
  Future<Result<NostrDescriptorPublication, BullVaultFailure>>
  publishDescriptorToNostr(String walletId, {NostrSession? session}) async {
    nostrPublications++;
    if (publishFailure != null) return Err(publishFailure!);
    final relay = Uri.parse('wss://relay.example');
    await _write(
      publications.prepare(
        walletId: walletId,
        destination: VaultBackupDestination.nostr,
        artifact: Uint8List.fromList([1, 2, 3]),
      ),
    );
    if (!relaysAccept) {
      await _write(
        publications.markFailed(
          walletId: walletId,
          destination: VaultBackupDestination.nostr,
        ),
      );
      return const Err(BullVaultNostrUnreachableFailure());
    }
    await _write(
      publications.markSent(
        walletId: walletId,
        destination: VaultBackupDestination.nostr,
      ),
    );
    return Ok(
      NostrDescriptorPublication(
        eventId: 'a' * 64,
        outcomes: {relay: NostrRelayOutcome.accepted},
      ),
    );
  }

  @override
  Future<Result<void, BullVaultFailure>> recordDescriptorPublicationSent({
    required String walletId,
    required VaultBackupDestination destination,
    required bool accepted,
  }) => accepted
      ? publications.markSent(walletId: walletId, destination: destination)
      : publications.markFailed(walletId: walletId, destination: destination);
}

final class _FakeServer extends Fake implements WalletBackupFacade {
  bool accepts = true;
  final sent = <Uint8List>[];

  @override
  Future<Result<DateTime, WalletBackupFailure>> publishPrivateDescriptor(
    String walletId, {
    BullVaultDescriptorBackup? prepared,
  }) async {
    sent.add(Uint8List.fromList(prepared!.bytes));
    return accepts
        ? Ok(DateTime.utc(2027))
        : const Err(WalletBackupRemoteUnavailableFailure());
  }
}

void main() {
  late SqliteDatabase database;
  late VaultDescriptorPublicationRepository publications;
  late _FakeVaults vaults;
  late _FakeServer server;
  late PublishVaultDescriptorBackupsUsecase publish;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    publications = VaultDescriptorPublicationRepository(database);
    vaults = _FakeVaults(publications);
    server = _FakeServer();
    publish = PublishVaultDescriptorBackupsUsecase(vaults, server);
  });

  Future<void> enable(VaultBackupDestination destination) async => publications
      .setEnabled(walletId: 'vault', destination: destination, enabled: true);

  /// Runs a publication and asserts it reported the rows it left behind.
  Future<void> ran(
    Future<Result<List<VaultDescriptorPublication>, BackupSettingsFailure>>
    attempt,
  ) async => expect(
    await attempt,
    isA<Ok<List<VaultDescriptorPublication>, BackupSettingsFailure>>(),
  );

  Future<VaultDescriptorPublication?> row(
    VaultBackupDestination destination,
  ) async =>
      (await publications.load('vault')
              as Ok<List<VaultDescriptorPublication>, BullVaultFailure>)
          .value
          .where((stored) => stored.destination == destination)
          .firstOrNull;

  test('a vault that selected nothing publishes nothing', () async {
    final result = await publish.execute('vault');

    expect(
      result,
      isA<Ok<List<VaultDescriptorPublication>, BackupSettingsFailure>>(),
    );
    expect(vaults.nostrPublications, 0);
    expect(vaults.preparations, 0);
    expect(server.sent, isEmpty);
  });

  test('a disabled destination is never sent to', () async {
    await enable(VaultBackupDestination.server);

    await ran(publish.execute('vault'));

    expect(server.sent, hasLength(1));
    expect(vaults.nostrPublications, 0);
  });

  test('both selected destinations are sent the artifact they own', () async {
    await enable(VaultBackupDestination.server);
    await enable(VaultBackupDestination.nostr);

    await ran(publish.execute('vault'));

    expect(server.sent.single, orderedEquals(_serverArtifact));
    expect(vaults.nostrPublications, 1);
    expect(
      (await row(VaultBackupDestination.server))!.state,
      VaultPublicationState.sent,
    );
    expect(
      (await row(VaultBackupDestination.nostr))!.state,
      VaultPublicationState.sent,
    );
  });

  test(
    'a refused server send leaves the artifact for the next retry',
    () async {
      await enable(VaultBackupDestination.server);
      server.accepts = false;

      await ran(publish.execute('vault'));

      final stored = await row(VaultBackupDestination.server);
      expect(stored!.state, VaultPublicationState.failed);
      expect(stored.artifact, orderedEquals(_serverArtifact));
      expect(stored.outstanding, isTrue);
    },
  );

  test(
    'a retry resends the same bytes and never seals a second artifact',
    () async {
      await enable(VaultBackupDestination.server);
      server.accepts = false;
      await ran(publish.execute('vault'));

      server.accepts = true;
      await ran(publish.retryPendingPublications('vault'));

      expect(server.sent, hasLength(2));
      expect(server.sent.first, orderedEquals(server.sent.last));
      final stored = await row(VaultBackupDestination.server);
      expect(stored!.state, VaultPublicationState.sent);
      expect(stored.attempts, 2);
    },
  );

  test('a retry skips a destination that already acknowledged', () async {
    await enable(VaultBackupDestination.server);
    await enable(VaultBackupDestination.nostr);
    await ran(publish.execute('vault'));

    final again = await publish.retryPendingPublications('vault');

    expect(server.sent, hasLength(1), reason: 'nothing was outstanding');
    expect(vaults.nostrPublications, 1);
    expect(
      (again as Ok<List<VaultDescriptorPublication>, BackupSettingsFailure>)
          .value
          .map((stored) => stored.state),
      everyElement(VaultPublicationState.sent),
    );
  });

  test(
    'a retry skips a selected destination that was never prepared',
    () async {
      await enable(VaultBackupDestination.server);

      await ran(publish.retryPendingPublications('vault'));

      expect(server.sent, isEmpty, reason: 'no artifact is owed yet');
      expect(vaults.preparations, 0);
    },
  );

  test('an artifact that cannot be sealed is a failure to retry', () async {
    await enable(VaultBackupDestination.server);
    vaults.sealFailure = const BullVaultInvalidRecoveryFailure();

    await ran(publish.execute('vault'));

    expect(server.sent, isEmpty);
    final stored = await row(VaultBackupDestination.server);
    expect(stored!.state, VaultPublicationState.failed);
    expect(stored.artifact, isNull);
    expect(
      stored.outstanding,
      isTrue,
      reason: 'the retry is what builds the artifact',
    );
  });

  test('a relay publisher that failed early is retried too', () async {
    await enable(VaultBackupDestination.nostr);
    vaults.publishFailure = const BullVaultBackupCredentialFailure();

    await ran(publish.execute('vault'));

    final stored = await row(VaultBackupDestination.nostr);
    expect(stored!.state, VaultPublicationState.failed);
    expect(stored.outstanding, isTrue);
  });

  test('a rejected relay send is counted once', () async {
    await enable(VaultBackupDestination.nostr);
    vaults.relaysAccept = false;

    await ran(publish.execute('vault'));

    final stored = await row(VaultBackupDestination.nostr);
    expect(stored!.state, VaultPublicationState.failed);
    expect(
      stored.attempts,
      1,
      reason: 'the publisher already wrote the refusal down',
    );
    expect(stored.outstanding, isTrue);
  });

  test('a relay failure does not stop the server destination', () async {
    await enable(VaultBackupDestination.server);
    await enable(VaultBackupDestination.nostr);
    vaults.relaysAccept = false;

    await ran(publish.execute('vault'));

    expect(server.sent, hasLength(1));
    expect(
      (await row(VaultBackupDestination.server))!.state,
      VaultPublicationState.sent,
    );
    expect(
      (await row(VaultBackupDestination.nostr))!.state,
      VaultPublicationState.failed,
    );
  });
}
