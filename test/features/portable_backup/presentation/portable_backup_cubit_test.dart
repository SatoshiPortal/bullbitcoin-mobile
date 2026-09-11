import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/portable_backup_fake.dart';

void main() {
  test(
    'cancelled lookup cannot repopulate state when its request completes',
    () async {
      final repository = PortableBackupFake()
        ..fetchPending =
            Completer<Result<PortableBackupFetch, PortableBackupFailure>>();
      final cubit = repository.cubit();
      addTearDown(cubit.close);
      final operation = cubit.fetch(
        words: testWords,
        network: 'testnet4',
        relay: 'wss://nos.lol',
      );
      expect(cubit.state.busy, isTrue);
      cubit.cancel();
      final cleared = cubit.state;
      expect(repository.fetchSession!.isCancelled, isTrue);
      repository.fetchPending!.complete(Ok(repository.recovered));
      await operation;
      expect(identical(cubit.state, cleared), isTrue);
      expect(cubit.state.recovered, isNull);
    },
  );

  test(
    'metadata opening emits success without retaining plaintext or publishing',
    () async {
      final repository = PortableBackupFake();
      final cubit = repository.cubit();
      addTearDown(cubit.close);
      await cubit.openMetadata(
        words: testWords,
        encodedFile: base64Encode(repository.files.metadata),
        network: 'testnet4',
      );
      expect(cubit.state.metadataOpened, isTrue);
      expect(cubit.state.recovered, isNull);
      expect(cubit.state.files, isNull);
      expect(cubit.state.publishedEventId, isNull);
      expect(cubit.state.failure, isNull);
      expect(repository.publishCalls, 0);
    },
  );
}
