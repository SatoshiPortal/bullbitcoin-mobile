import 'dart:async';

import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';

import 'package:flutter_test/flutter_test.dart';

import '../support/portable_backup_fake.dart';

void main() {
  test(
    'publishes only the vault and preserves both files on relay failure',
    () async {
      final repository = PortableBackupFake()
        ..publication = const Err(PortableBackupNetworkFailure());
      final result = await repository.prepareAndPublish.execute(
        words: testWords,
        metadataJson: privateMetadata,
        descriptor: 'public descriptor',
        network: 'testnet4',
        relay: 'wss://nos.lol',
        session: NostrSession(),
      );
      final outcome =
          (result as Ok<PortableBackupPublication, PortableBackupFailure>)
              .value;
      expect(repository.publishCalls, 1);
      expect(repository.publishedFile, repository.files.vault);
      expect(repository.publishedFile, isNot(repository.files.metadata));
      expect(outcome.files.metadata, repository.files.metadata);
      expect(outcome.files.vault, repository.files.vault);
      expect(outcome.publication, isA<Err<String, PortableBackupFailure>>());
    },
  );

  test(
    'cancellation during encryption prevents subsequent publication',
    () async {
      final repository = PortableBackupFake()
        ..preparePending =
            Completer<Result<PortableBackupFiles, PortableBackupFailure>>();
      final session = NostrSession();
      final operation = repository.prepareAndPublish.execute(
        words: testWords,
        metadataJson: privateMetadata,
        descriptor: 'public descriptor',
        network: 'testnet4',
        relay: 'wss://nos.lol',
        session: session,
      );
      session.cancel();
      repository.preparePending!.complete(Ok(repository.files));
      final result = await operation;
      expect(
        result,
        isA<Err<PortableBackupPublication, PortableBackupFailure>>(),
      );
      expect(repository.publishCalls, 0);
    },
  );
}
