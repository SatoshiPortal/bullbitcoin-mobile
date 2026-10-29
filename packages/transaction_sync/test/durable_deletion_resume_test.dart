import 'dart:io';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'support/fakes.dart';

void main() {
  test('discovery re-registers after resuming a durable deletion', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sync-delete-resume-',
    );
    final metadata = await SqliteWalletSyncMetadataStore.open(
      databasePath: '${directory.path}/metadata.sqlite',
    );
    final source = RecordingSource();
    final facade = WalletTransactionSyncFacade(
      source: source,
      metadata: metadata,
      coordinator: InMemoryWalletSourceOperationCoordinator(),
    );
    addTearDown(() async {
      await facade.dispose();
      await metadata.close();
      await directory.delete(recursive: true);
    });
    await metadata.writeRegistration(testRegistration);
    await metadata.writeDeletionMarker(
      testKey,
      WalletDeletionPhase.markerWritten,
    );
    final result = await facade.discoverWalletHistory(
      const DiscoverWalletHistoryRequest(testRegistration),
    );
    expect(
      result,
      isA<Ok<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>(),
    );
    expect(source.deleteCalls, 1);
    expect(source.syncCalls, 1);
    expect((await metadata.read(testKey))?.deletionPending, isFalse);
    expect(await metadata.readReceipt(testKey), isNotNull);
  });
}
