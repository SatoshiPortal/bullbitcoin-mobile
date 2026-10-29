import 'package:primitives/primitives.dart';
import 'dart:io';
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'support/fakes.dart';

void main() {
  for (final admitted in [false, true]) {
    test(
      'discovery resumes durable deletion ${admitted ? 'in an admitted session' : 'with normal admission'}',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cbf-delete-resume-',
        );
        final metadata = await SqliteWalletSyncMetadataStore.open(
          databasePath: '${directory.path}/metadata.sqlite',
        );
        final coordinator = InMemoryWalletSourceOperationCoordinator();
        final source = RecordingSource();
        final facade = WalletTransactionSyncFacade(
          source: source,
          metadata: metadata,
          coordinator: coordinator,
        );
        await metadata.writeRegistration(testRegistration);
        await metadata.writeDeletionMarker(
          testKey,
          WalletDeletionPhase.markerWritten,
        );
        final result = admitted
            ? await coordinator.runExclusive(
                const WalletSourceKey('w', 'bitcoin', 'testnet'),
                (session) => facade.discoverWalletHistory(
                  DiscoverWalletHistoryRequest(
                    testRegistration,
                    session: session,
                  ),
                ),
                timeout: null,
              )
            : await facade.discoverWalletHistory(
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
        await facade.dispose();
        await metadata.close();
        await directory.delete(recursive: true);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  }
}
